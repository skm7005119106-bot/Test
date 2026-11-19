import { z } from "zod";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { KAYRA_PERSONA, MEMORY_INSTRUCTIONS, buildUserContext } from "./persona.js";

// Haiku keeps the per-message cost low enough for a free tier. Change it with
// the KAYRA_MODEL environment variable.
export const MODEL = process.env.KAYRA_MODEL || "claude-haiku-5-5";

const DEFAULT_SUGGESTIONS = ["Haan", "Tum batao", "Aur kya chal raha hai?"];
const REFUSAL = {
  message: "Hmm, is baare me main baat nahi kar paungi 🙈 Chalo kuch aur batao, aaj din kaisa raha?",
  suggestions: ["Theek hai", "Din achha tha", "Tum batao"],
};
const EMPTY = {
  message: "Arre, mera dhyaan bhatak gaya tha 😅 Ek baar phir bolo na?",
  suggestions: DEFAULT_SUGGESTIONS,
};

const ReplySchema = z.object({
  message: z.string(),
  suggestions: z.array(z.string()),
});

function cleanSuggestions(list) {
  const clean = (list || [])
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && s.length <= 40)
    .slice(0, 3);
  return clean.length > 0 ? clean : DEFAULT_SUGGESTIONS;
}

/** Kayra's next message and three suggested replies, given the recent conversation. */
export async function generateReply(client, { user, memory, history, now }) {
  const response = await client.messages.parse({
    model: MODEL,
    max_tokens: 4000,
    output_config: { effort: "low", format: zodOutputFormat(ReplySchema) },
    system: [
      { type: "text", text: KAYRA_PERSONA, cache_control: { type: "ephemeral" } },
      { type: "text", text: buildUserContext({ user, memory, now }) },
    ],
    messages: history.map((m) => ({ role: m.role, content: m.text })),
  });

  if (response.stop_reason === "refusal") return REFUSAL;
  const parsed = response.parsed_output;
  const message = parsed?.message?.trim();
  if (!message) return EMPTY;
  return { message: message.slice(0, 2000), suggestions: cleanSuggestions(parsed.suggestions) };
}

const MemorySchema = z.object({ facts: z.array(z.string()) });

/** A refreshed list of facts about the user, or null if it could not be built. */
export async function refreshMemory(client, { memory, forgotten, history, maxFacts }) {
  const transcript = history.map((m) => `${m.role === "user" ? "User" : "Kayra"}: ${m.text}`).join("\n");
  const list = (items) => (items.length > 0 ? items.map((f) => `- ${f}`).join("\n") : "(kuch nahi)");

  const response = await client.messages.parse({
    model: MODEL,
    max_tokens: 4000,
    output_config: { effort: "low", format: zodOutputFormat(MemorySchema) },
    system: `${MEMORY_INSTRUCTIONS}\n\nZyada se zyada ${maxFacts} facts; agar zyada ho jaayen to sabse kam zaroori hata do.`,
    messages: [
      {
        role: "user",
        content: `Pehle se yaad baatein:\n${list(memory)}\n\nUser ne yeh bhoolne ko kaha hai:\n${list(forgotten)}\n\nBaatcheet:\n${transcript}`,
      },
    ],
  });

  const facts = response.parsed_output?.facts;
  if (!facts) return null;
  return facts
    .map((f) => f.trim().slice(0, 200))
    .filter(Boolean)
    .slice(0, maxFacts);
}
