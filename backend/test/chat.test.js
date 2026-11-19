import assert from "node:assert/strict";
import { test } from "node:test";
import Anthropic from "@anthropic-ai/sdk";
import { generateReply, refreshMemory } from "../src/chat.js";

// A real Anthropic client whose network calls return a canned Messages API response,
// so the SDK's request building and structured-output parsing run for real.
function clientReturning(text, { stop_reason = "end_turn" } = {}) {
  const requests = [];
  const client = new Anthropic({
    apiKey: "test-key",
    baseURL: "http://claude.test",
    fetch: async (url, init) => {
      requests.push({ url: String(url), body: JSON.parse(init.body) });
      const body = {
        id: "msg_test",
        type: "message",
        role: "assistant",
        model: "claude-haiku-5-5",
        content: text === null ? [] : [{ type: "text", text }],
        stop_reason,
        stop_sequence: null,
        usage: { input_tokens: 10, output_tokens: 5 },
      };
      return new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
    },
  });
  return { client, requests };
}

const user = { name: "Aman", nickname: "Jaan", mood: "funny", xp: 130, streak: 3 };

test("generateReply sends Kayra's prompt and parses her structured answer", async () => {
  const { client, requests } = clientReturning(
    JSON.stringify({ message: "Arre Jaan 😄", suggestions: ["Haan", "Tum batao", "Kuch nahi", "Extra"] }),
  );
  const reply = await generateReply(client, {
    user,
    memory: ["Pune me rehta hai"],
    history: [{ role: "user", text: "hi" }],
    now: new Date("2026-11-19T21:00:00+05:30"),
  });
  assert.deepEqual(reply, { message: "Arre Jaan 😄", suggestions: ["Haan", "Tum batao", "Kuch nahi"] });

  const sent = requests[0];
  assert.match(sent.url, /\/v1\/messages$/);
  assert.equal(sent.body.model, "claude-haiku-5-5");
  assert.equal(sent.body.output_config.effort, "low");
  assert.equal(sent.body.output_config.format.type, "json_schema");
  assert.deepEqual(sent.body.messages, [{ role: "user", content: "hi" }]);
  assert.match(sent.body.system[1].text, /crush hai/);
  assert.match(sent.body.system[1].text, /mood mazaakiya/);
  assert.match(sent.body.system[1].text, /raat/);
  assert.match(sent.body.system[1].text, /3 din se/);
  assert.match(sent.body.system[1].text, /- Pune me rehta hai/);
  assert.equal(sent.body.temperature, undefined);
});

test("generateReply turns a refusal into Kayra's gentle deflection", async () => {
  const { client } = clientReturning(null, { stop_reason: "refusal" });
  const reply = await generateReply(client, { user, memory: [], history: [{ role: "user", text: "x" }] });
  assert.match(reply.message, /baat nahi kar paungi/);
  assert.equal(reply.suggestions.length, 3);
});

test("refreshMemory parses the facts list", async () => {
  const { client, requests } = clientReturning(JSON.stringify({ facts: [" Chai pasand hai ", "", "Pune me rehta hai"] }));
  const facts = await refreshMemory(client, {
    memory: [],
    forgotten: ["Cricket pasand hai"],
    history: [{ role: "user", text: "main pune me rehta hoon" }],
    maxFacts: 20,
  });
  assert.deepEqual(facts, ["Chai pasand hai", "Pune me rehta hai"]);
  assert.match(requests[0].body.messages[0].content, /bhoolne ko kaha hai:\n- Cricket pasand hai/);
});
