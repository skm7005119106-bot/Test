import Anthropic from "@anthropic-ai/sdk";
import express from "express";
import { z } from "zod";
import { generateReply, updateMemory } from "./chat.js";

const HISTORY_LIMIT = 30;
const MEMORY_EVERY = 8; // refresh memory after every 8th message of the day

const DeviceId = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);

const ChatRequest = z.object({
  deviceId: DeviceId,
  profile: z.object({
    name: z.string().trim().min(1).max(40),
    nickname: z.string().trim().max(40).optional(),
  }),
  memory: z.array(z.string().max(200)).max(20).default([]),
  messages: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        text: z.string().trim().min(1).max(1000),
      }),
    )
    .min(1)
    .max(100),
});

const ReportRequest = z.object({
  deviceId: DeviceId,
  message: z.string().trim().min(1).max(2000),
  reason: z.string().trim().max(500).default(""),
});

/**
 * The HTTP API. `client` is the Anthropic client, `store` keeps daily counts
 * and reports, `freeDailyLimit` is how many messages a device gets per day.
 */
export function createApp({ client, store, freeDailyLimit = 30, now = () => new Date() }) {
  const app = express();
  app.use(express.json({ limit: "200kb" }));

  // The Flutter web build calls this API from another origin.
  app.use((req, res, next) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
  });

  app.get("/health", (_req, res) => res.json({ ok: true }));

  app.post("/chat", async (req, res) => {
    const parsed = ChatRequest.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
    const { deviceId, profile, memory } = parsed.data;

    // Keep the most recent messages, starting from a user message as the API requires.
    let messages = parsed.data.messages.slice(-HISTORY_LIMIT);
    while (messages.length > 0 && messages[0].role !== "user") messages = messages.slice(1);
    if (messages.length === 0 || messages.at(-1).role !== "user") {
      return res.status(400).json({ error: "invalid_request" });
    }

    const time = now();
    const used = store.usedToday(deviceId, time);
    if (used >= freeDailyLimit) {
      return res.status(429).json({ error: "daily_limit", limit: freeDailyLimit, remaining: 0 });
    }

    let reply;
    try {
      reply = await generateReply(client, { profile, memory, messages, now: time });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        return res.status(503).json({ error: "busy" });
      }
      if (error instanceof Anthropic.APIError) {
        console.error(`Claude API error ${error.status}: ${error.message}`);
        return res.status(502).json({ error: "ai_unavailable" });
      }
      console.error(error);
      return res.status(500).json({ error: "server_error" });
    }

    store.recordMessage(deviceId, time);
    const usedNow = used + 1;
    const body = { reply, limit: freeDailyLimit, remaining: freeDailyLimit - usedNow };

    if (usedNow % MEMORY_EVERY === 0) {
      try {
        const facts = await updateMemory(client, {
          memory,
          messages: [...messages, { role: "assistant", text: reply }],
        });
        if (facts) body.memory = facts;
      } catch (error) {
        // Memory is a nice-to-have: the reply still goes out without it.
        console.error("Memory update failed:", error.message);
      }
    }

    res.json(body);
  });

  app.post("/report", (req, res) => {
    const parsed = ReportRequest.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
    store.addReport(parsed.data, now());
    res.json({ ok: true });
  });

  return app;
}
