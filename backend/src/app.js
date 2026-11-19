import { createHash, randomBytes } from "node:crypto";
import Anthropic from "@anthropic-ai/sdk";
import express from "express";
import { z } from "zod";
import { generateReply, refreshMemory } from "./chat.js";
import { deleteAccountPage, privacyPage } from "./pages.js";
import { XP_PER_MESSAGE, indiaDate, levelIndex, LEVELS, moodLock, nextStreak, progressOf } from "./progress.js";

const HISTORY_FOR_AI = 30;     // messages Kayra reads before replying
const HISTORY_FOR_APP = 200;   // messages the app gets when it opens
const MEMORY_EVERY = 8;        // refresh memories after every 8th message
const REACTIONS = ["❤️", "😂", "😮", "🥺", "🔥"];

const sha256 = (text) => createHash("sha256").update(text).digest("hex");

/** The id the app sends to Google Play with a purchase, so a token can be tied to its buyer. */
export const purchaseAccountId = (userId) => sha256(`kayra:${userId}`);

const Body = {
  googleSignIn: z.object({ idToken: z.string().min(10).max(5000) }),
  profile: z.object({
    name: z.string().trim().min(1).max(40).optional(),
    nickname: z.string().trim().max(40).optional(),
    mood: z.string().max(20).optional(),
  }),
  chat: z.object({ text: z.string().trim().min(1).max(1000) }),
  reaction: z.object({ emoji: z.enum(REACTIONS).nullable() }),
  report: z.object({ messageId: z.number().int().positive(), reason: z.string().trim().max(500).default("") }),
  purchase: z.object({ productId: z.string().min(1).max(100), purchaseToken: z.string().min(10).max(1000) }),
};

/** Tiny fixed-window limiter, per key, kept in memory. */
function rateLimiter({ limit, windowMs }) {
  const hits = new Map();
  return (key, now = Date.now()) => {
    const entry = hits.get(key);
    if (!entry || now - entry.start > windowMs) {
      hits.set(key, { start: now, count: 1 });
      if (hits.size > 10_000) hits.clear();
      return true;
    }
    entry.count += 1;
    return entry.count <= limit;
  };
}

/**
 * The HTTP API.
 * - `db`: from openDb()
 * - `claude`: Anthropic client
 * - `verifyGoogleToken(idToken)` -> {id, email, name}
 * - `verifyPurchase(token)` -> {productId, expiry, active, accountId}, or null when billing isn't set up
 */
export function createApp({
  db,
  claude,
  verifyGoogleToken,
  verifyPurchase = null,
  config = {},
  now = () => new Date(),
}) {
  const {
    freeDailyLimit = 30,
    plusDailyLimit = 300,
    freeMemory = 20,
    plusMemory = 40,
    plusProducts = ["kayra_plus_monthly", "kayra_plus_yearly"],
    supportEmail = "",
    policyUpdated = "19 November 2026",
  } = config;

  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", 1);
  app.use(express.json({ limit: "50kb" }));

  // Background work (memory refresh) that tests can wait for.
  const pending = new Set();
  app.idle = () => Promise.allSettled([...pending]);
  const background = (promise) => {
    pending.add(promise);
    promise.finally(() => pending.delete(promise));
  };

  const signInLimit = rateLimiter({ limit: 20, windowMs: 60_000 });
  const chatBurst = rateLimiter({ limit: 20, windowMs: 60_000 });

  const isPlus = (user) => user.plus_until > now().getTime();
  const dailyLimit = (user) => (isPlus(user) ? plusDailyLimit : freeDailyLimit);
  const memoryLimit = (user) => (isPlus(user) ? plusMemory : freeMemory);

  async function usedToday(userId) {
    const row = await db.get("SELECT count FROM usage WHERE user_id = ? AND day = ?", [userId, indiaDate(now())]);
    return row?.count ?? 0;
  }

  async function memoriesOf(userId) {
    return db.all("SELECT id, fact FROM memories WHERE user_id = ? ORDER BY id", [userId]);
  }

  async function recentMessages(userId, limit) {
    const rows = await db.all(
      "SELECT id, role, text, reaction, created_at FROM messages WHERE user_id = ? ORDER BY id DESC LIMIT ?",
      [userId, limit],
    );
    return rows.reverse();
  }

  const messageJson = (m) => ({ id: m.id, role: m.role, text: m.text, reaction: m.reaction ?? null, time: m.created_at });

  async function addMessage(userId, role, text, time) {
    const row = await db.get(
      "INSERT INTO messages (user_id, role, text, created_at) VALUES (?, ?, ?, ?) RETURNING id",
      [userId, role, text, time],
    );
    return { id: row.id, role, text, reaction: null, created_at: time };
  }

  async function mePayload(user) {
    const used = await usedToday(user.id);
    const limit = dailyLimit(user);
    return {
      profile: { name: user.name, nickname: user.nickname, mood: user.mood, email: user.email },
      progress: progressOf(user),
      plus: { active: isPlus(user), until: user.plus_until || null, productId: user.plus_product || null },
      usage: { limit, remaining: Math.max(0, limit - used) },
      memory: { items: await memoriesOf(user.id), limit: memoryLimit(user) },
      messages: (await recentMessages(user.id, HISTORY_FOR_APP)).map(messageJson),
      purchaseAccountId: purchaseAccountId(user.id),
    };
  }

  // Wraps a route so thrown errors become a 500 instead of crashing the request.
  const route = (handler) => async (req, res) => {
    try {
      await handler(req, res);
    } catch (error) {
      console.error(`${req.method} ${req.path} failed:`, error);
      if (!res.headersSent) res.status(500).json({ error: "server_error" });
    }
  };

  const parse = (schema, req, res) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      res.status(400).json({ error: "invalid_request" });
      return null;
    }
    return result.data;
  };

  // Every route below `authed` needs `Authorization: Bearer <session token>`.
  const authed = (handler) =>
    route(async (req, res) => {
      const match = /^Bearer (\S{20,200})$/.exec(req.get("authorization") || "");
      const session = match
        ? await db.get("SELECT user_id FROM sessions WHERE token_hash = ?", [sha256(match[1])])
        : null;
      const user = session ? await db.get("SELECT * FROM users WHERE id = ?", [session.user_id]) : null;
      if (!user) return res.status(401).json({ error: "signed_out" });
      req.user = user;
      req.sessionHash = sha256(match[1]);
      await handler(req, res);
    });

  // ---- Public pages ----

  app.get("/health", (_req, res) => res.json({ ok: true }));
  app.get("/privacy", (_req, res) => res.type("html").send(privacyPage({ supportEmail, updated: policyUpdated })));
  app.get("/delete-account", (_req, res) => res.type("html").send(deleteAccountPage({ supportEmail })));

  // ---- Sign in ----

  app.post(
    "/auth/google",
    route(async (req, res) => {
      if (!signInLimit(req.ip)) return res.status(429).json({ error: "too_many_requests" });
      const body = parse(Body.googleSignIn, req, res);
      if (!body) return;
      let account;
      try {
        account = await verifyGoogleToken(body.idToken);
      } catch {
        return res.status(401).json({ error: "google_sign_in_failed" });
      }
      const time = now().getTime();
      await db.run(
        `INSERT INTO users (id, email, name, created_at) VALUES (?, ?, '', ?)
         ON CONFLICT (id) DO UPDATE SET email = excluded.email`,
        [account.id, account.email, time],
      );
      const token = randomBytes(32).toString("base64url");
      await db.run("INSERT INTO sessions (token_hash, user_id, created_at) VALUES (?, ?, ?)", [sha256(token), account.id, time]);
      const user = await db.get("SELECT * FROM users WHERE id = ?", [account.id]);
      res.json({ token, suggestedName: account.name, me: await mePayload(user) });
    }),
  );

  app.post(
    "/auth/sign-out",
    authed(async (req, res) => {
      await db.run("DELETE FROM sessions WHERE token_hash = ?", [req.sessionHash]);
      res.json({ ok: true });
    }),
  );

  // ---- Profile ----

  app.get("/me", authed(async (req, res) => res.json(await mePayload(req.user))));

  app.patch(
    "/me",
    authed(async (req, res) => {
      const body = parse(Body.profile, req, res);
      if (!body) return;
      const user = req.user;
      if (body.mood !== undefined) {
        const lock = moodLock(body.mood, { xp: user.xp, plus: isPlus(user) });
        if (lock) return res.status(403).json({ error: "mood_locked", reason: lock });
      }
      const firstSetup = !user.name && body.name;
      const updated = {
        name: body.name ?? user.name,
        nickname: body.nickname ?? user.nickname,
        mood: body.mood ?? user.mood,
      };
      if (!updated.name) return res.status(400).json({ error: "name_required" });
      await db.run("UPDATE users SET name = ?, nickname = ?, mood = ? WHERE id = ?", [
        updated.name,
        updated.nickname,
        updated.mood,
        user.id,
      ]);
      if (firstSetup) {
        const callName = updated.nickname || updated.name;
        await addMessage(
          user.id,
          "assistant",
          `Hii ${callName}! Main Kayra 💕 Finally aa gaye tum... batao, aaj ka din kaisa raha?`,
          now().getTime(),
        );
      }
      res.json(await mePayload({ ...user, ...updated }));
    }),
  );

  app.delete(
    "/me",
    authed(async (req, res) => {
      const id = req.user.id;
      for (const table of ["messages", "memories", "forgotten", "usage", "reports", "sessions"]) {
        await db.run(`DELETE FROM ${table} WHERE user_id = ?`, [id]);
      }
      await db.run("DELETE FROM users WHERE id = ?", [id]);
      res.json({ ok: true });
    }),
  );

  app.delete(
    "/me/messages",
    authed(async (req, res) => {
      await db.run("DELETE FROM messages WHERE user_id = ?", [req.user.id]);
      res.json({ ok: true });
    }),
  );

  // ---- Chat ----

  app.post(
    "/chat",
    authed(async (req, res) => {
      const body = parse(Body.chat, req, res);
      if (!body) return;
      const user = req.user;
      if (!user.name) return res.status(409).json({ error: "profile_incomplete" });
      if (!chatBurst(user.id)) return res.status(429).json({ error: "too_fast" });

      const limit = dailyLimit(user);
      const used = await usedToday(user.id);
      if (used >= limit) {
        return res.status(429).json({ error: "daily_limit", limit, remaining: 0, plus: isPlus(user) });
      }

      // Kayra reads the recent chat, starting from a user message as the API requires.
      let history = (await recentMessages(user.id, HISTORY_FOR_AI - 1)).map((m) => ({ role: m.role, text: m.text }));
      history.push({ role: "user", text: body.text });
      while (history.length > 0 && history[0].role !== "user") history = history.slice(1);

      const memory = (await memoriesOf(user.id)).map((m) => m.fact);
      let reply;
      try {
        reply = await generateReply(claude, { user, memory, history, now: now() });
      } catch (error) {
        if (error instanceof Anthropic.RateLimitError) return res.status(503).json({ error: "busy" });
        if (error instanceof Anthropic.APIError) {
          console.error(`Claude API error ${error.status}: ${error.message}`);
          return res.status(502).json({ error: "ai_unavailable" });
        }
        throw error;
      }

      // Only a delivered reply uses up a message and earns points.
      const time = now().getTime();
      const sent = await addMessage(user.id, "user", body.text, time);
      const answer = await addMessage(user.id, "assistant", reply.message, time + 1);
      await db.run(
        `INSERT INTO usage (user_id, day, count) VALUES (?, ?, 1)
         ON CONFLICT (user_id, day) DO UPDATE SET count = usage.count + 1`,
        [user.id, indiaDate(now())],
      );
      const streak = nextStreak({ streak: user.streak, lastDay: user.last_day }, now());
      const xp = user.xp + XP_PER_MESSAGE;
      const messageCount = user.message_count + 1;
      await db.run("UPDATE users SET xp = ?, streak = ?, last_day = ?, message_count = ? WHERE id = ?", [
        xp,
        streak.streak,
        streak.lastDay,
        messageCount,
        user.id,
      ]);
      const updated = { ...user, xp, streak: streak.streak, last_day: streak.lastDay, message_count: messageCount };
      const before = levelIndex(user.xp);
      const after = levelIndex(xp);

      if (messageCount % MEMORY_EVERY === 0) {
        background(
          (async () => {
            const forgotten = (
              await db.all("SELECT fact FROM forgotten WHERE user_id = ? ORDER BY id DESC LIMIT 50", [user.id])
            ).map((r) => r.fact);
            const facts = await refreshMemory(claude, {
              memory,
              forgotten,
              history: [...history, { role: "assistant", text: reply.message }],
              maxFacts: memoryLimit(user),
            });
            if (!facts) return;
            await db.run("DELETE FROM memories WHERE user_id = ?", [user.id]);
            for (const fact of facts) {
              await db.run("INSERT INTO memories (user_id, fact, created_at) VALUES (?, ?, ?)", [user.id, fact, Date.now()]);
            }
          })().catch((error) => console.error("Memory refresh failed:", error.message)),
        );
      }

      res.json({
        sent: messageJson(sent),
        reply: messageJson(answer),
        suggestions: reply.suggestions,
        progress: progressOf(updated),
        levelUp: after > before ? LEVELS[after].name : null,
        usage: { limit, remaining: Math.max(0, limit - used - 1) },
      });
    }),
  );

  app.put(
    "/messages/:id/reaction",
    authed(async (req, res) => {
      const body = parse(Body.reaction, req, res);
      if (!body) return;
      const id = Number(req.params.id);
      const result = await db.run(
        "UPDATE messages SET reaction = ? WHERE id = ? AND user_id = ? AND role = 'assistant'",
        [body.emoji, id, req.user.id],
      );
      const changed = result.changes ?? result.rowCount;
      if (!changed) return res.status(404).json({ error: "not_found" });
      res.json({ ok: true });
    }),
  );

  app.post(
    "/report",
    authed(async (req, res) => {
      const body = parse(Body.report, req, res);
      if (!body) return;
      const message = await db.get("SELECT text FROM messages WHERE id = ? AND user_id = ?", [body.messageId, req.user.id]);
      if (!message) return res.status(404).json({ error: "not_found" });
      await db.run("INSERT INTO reports (user_id, message_id, text, reason, created_at) VALUES (?, ?, ?, ?, ?)", [
        req.user.id,
        body.messageId,
        message.text,
        body.reason,
        now().getTime(),
      ]);
      res.json({ ok: true });
    }),
  );

  // ---- Memories ----

  app.delete(
    "/memories/:id",
    authed(async (req, res) => {
      const id = Number(req.params.id);
      const memory = await db.get("SELECT fact FROM memories WHERE id = ? AND user_id = ?", [id, req.user.id]);
      if (!memory) return res.status(404).json({ error: "not_found" });
      await db.run("DELETE FROM memories WHERE id = ?", [id]);
      await db.run("INSERT INTO forgotten (user_id, fact, created_at) VALUES (?, ?, ?)", [
        req.user.id,
        memory.fact,
        now().getTime(),
      ]);
      res.json({ items: await memoriesOf(req.user.id), limit: memoryLimit(req.user) });
    }),
  );

  // ---- Kayra Plus ----

  app.post(
    "/billing/google-play",
    authed(async (req, res) => {
      const body = parse(Body.purchase, req, res);
      if (!body) return;
      if (!verifyPurchase) return res.status(503).json({ error: "billing_not_configured" });
      if (!plusProducts.includes(body.productId)) return res.status(400).json({ error: "unknown_product" });

      const owner = await db.get("SELECT user_id FROM purchases WHERE token = ?", [body.purchaseToken]);
      if (owner && owner.user_id !== req.user.id) return res.status(409).json({ error: "purchase_belongs_to_another_account" });

      let purchase;
      try {
        purchase = await verifyPurchase(body.purchaseToken);
      } catch (error) {
        console.error("Play verification failed:", error.message);
        return res.status(400).json({ error: "purchase_not_verified" });
      }
      if (purchase.accountId && purchase.accountId !== purchaseAccountId(req.user.id)) {
        return res.status(409).json({ error: "purchase_belongs_to_another_account" });
      }
      if (!plusProducts.includes(purchase.productId)) return res.status(400).json({ error: "unknown_product" });

      const time = now().getTime();
      await db.run(
        `INSERT INTO purchases (token, user_id, product_id, expiry, state, updated_at) VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT (token) DO UPDATE SET expiry = excluded.expiry, state = excluded.state, updated_at = excluded.updated_at`,
        [body.purchaseToken, req.user.id, purchase.productId, purchase.expiry, purchase.state || "", time],
      );
      const until = purchase.active && purchase.expiry > time ? purchase.expiry : 0;
      if (until > req.user.plus_until || (until === 0 && req.user.plus_product === purchase.productId)) {
        await db.run("UPDATE users SET plus_until = ?, plus_product = ? WHERE id = ?", [until, purchase.productId, req.user.id]);
      }
      const user = await db.get("SELECT * FROM users WHERE id = ?", [req.user.id]);
      res.json(await mePayload(user));
    }),
  );

  return app;
}
