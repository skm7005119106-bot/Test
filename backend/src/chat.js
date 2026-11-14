import { z } from "zod";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { KAYRA_PERSONA, MEMORY_INSTRUCTIONS, buildUserContext } from "./persona.js";

// Haiku keeps the per-message cost low enough for a free tier. Change it with
// the KAYRA_MODEL environment variable (e.g. claude-sonnet-5-5 for premium).
export const MODEL = process.env.KAYRA_MODEL || "claude-haiku-5-5";

const REFUSAL_REPLY = "Hmm, is baare me main baat nahi kar paungi 🙈 Chalo kuch aur batao, aaj din kaisa raha?";
const EMPTY_REPLY = "Arre, mera dhyaan bhatak gaya tha 😅 Ek baar phir bolo na?";

function toApiMessages(messages) {
  return messages.map((m) => ({ role: m.role, content: m.text }));
}

function textOf(response) {
  return response.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("")
    .trim();
}

/** Kayra's next message, given the recent conversation. */
export async function generateReply(client, { profile, memory, messages, now }) {
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 4000,
    output_config: { effort: "low" },
    system: [
      { type: "text", text: KAYRA_PERSONA, cache_control: { type: "ephemeral" } },
      { type: "text", text: buildUserContext({ profile, memory, now }) },
    ],
    messages: toApiMessages(messages),
  });

  if (response.stop_reason === "refusal") return REFUSAL_REPLY;
  return textOf(response) || EMPTY_REPLY;
}

const MemorySchema = z.object({ facts: z.array(z.string()) });

/** A refreshed list of facts about the user, or null if it could not be built. */
export async function updateMemory(client, { memory, messages }) {
  const transcript = messages
    .map((m) => `${m.role === "user" ? "User" : "Kayra"}: ${m.text}`)
    .join("\n");
  const known = memory.length > 0 ? memory.map((f) => `- ${f}`).join("\n") : "(abhi kuch nahi)";

  const response = await client.messages.parse({
    model: MODEL,
    max_tokens: 4000,
    output_config: { effort: "low", format: zodOutputFormat(MemorySchema) },
    system: MEMORY_INSTRUCTIONS,
    messages: [
      {
        role: "user",
        content: `Pehle se yaad baatein:\n${known}\n\nBaatcheet:\n${transcript}`,
      },
    ],
  });

  const facts = response.parsed_output?.facts;
  if (!facts) return null;
  return facts
    .map((f) => f.trim().slice(0, 200))
    .filter(Boolean)
    .slice(0, 20);
}
