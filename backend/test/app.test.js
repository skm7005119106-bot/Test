import assert from "node:assert/strict";
import { test } from "node:test";
import Anthropic from "@anthropic-ai/sdk";
import { createApp } from "../src/app.js";
import { openStore, indiaDate } from "../src/store.js";

const DEVICE = "device_1234567890abcdef";

function fakeClient({ reply = "Hii baby 💕", stopReason = "end_turn", facts = ["Naam Aman hai"], fail } = {}) {
  const calls = { create: [], parse: [] };
  return {
    calls,
    messages: {
      async create(params) {
        calls.create.push(params);
        if (fail) throw fail;
        return {
          stop_reason: stopReason,
          content: [
            { type: "thinking", thinking: "" },
            { type: "text", text: reply },
          ],
        };
      },
      async parse(params) {
        calls.parse.push(params);
        return { parsed_output: { facts } };
      },
    },
  };
}

async function withServer(options, run) {
  const store = openStore();
  const app = createApp({ store, ...options });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = async (path, body) => {
    const res = await fetch(base + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  };
  try {
    await run({ post, store });
  } finally {
    server.close();
    store.close();
  }
}

const chatBody = (overrides = {}) => ({
  deviceId: DEVICE,
  profile: { name: "Aman", nickname: "Jaan" },
  memory: ["Pune me rehta hai"],
  messages: [{ role: "user", text: "hii kayra" }],
  ...overrides,
});

test("chat returns Kayra's reply and the remaining free messages", async () => {
  const client = fakeClient();
  await withServer({ client, freeDailyLimit: 5 }, async ({ post }) => {
    const res = await post("/chat", chatBody());
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { reply: "Hii baby 💕", limit: 5, remaining: 4 });

    const sent = client.calls.create[0];
    assert.equal(sent.model, "claude-haiku-5-5");
    assert.match(sent.system[0].text, /Tum Kayra ho/);
    assert.match(sent.system[1].text, /Jaan/);
    assert.match(sent.system[1].text, /Pune me rehta hai/);
    assert.deepEqual(sent.messages, [{ role: "user", content: "hii kayra" }]);
  });
});

test("chat is blocked once the daily limit is used up", async () => {
  const client = fakeClient();
  await withServer({ client, freeDailyLimit: 2 }, async ({ post }) => {
    assert.equal((await post("/chat", chatBody())).body.remaining, 1);
    assert.equal((await post("/chat", chatBody())).body.remaining, 0);
    const blocked = await post("/chat", chatBody());
    assert.equal(blocked.status, 429);
    assert.equal(blocked.body.error, "daily_limit");
    assert.equal(client.calls.create.length, 2);
  });
});

test("the limit resets on the next India day and is per device", async () => {
  const client = fakeClient();
  let time = new Date("2026-11-14T10:00:00+05:30");
  await withServer({ client, freeDailyLimit: 1, now: () => time }, async ({ post }) => {
    assert.equal((await post("/chat", chatBody())).status, 200);
    assert.equal((await post("/chat", chatBody())).status, 429);
    assert.equal((await post("/chat", chatBody({ deviceId: "another_device_0123456789" }))).status, 200);
    time = new Date("2026-11-15T00:05:00+05:30");
    assert.equal((await post("/chat", chatBody())).status, 200);
  });
  assert.equal(indiaDate(new Date("2026-11-14T19:00:00Z")), "2026-11-15");
});

test("memory is refreshed on every 8th message", async () => {
  const client = fakeClient({ facts: ["Naam Aman hai", "  Chai pasand hai  ", ""] });
  await withServer({ client, freeDailyLimit: 30 }, async ({ post }) => {
    for (let i = 0; i < 7; i++) {
      assert.equal((await post("/chat", chatBody())).body.memory, undefined);
    }
    const eighth = await post("/chat", chatBody());
    assert.deepEqual(eighth.body.memory, ["Naam Aman hai", "Chai pasand hai"]);
    assert.equal(client.calls.parse.length, 1);
    assert.match(client.calls.parse[0].messages[0].content, /Kayra: Hii baby/);
  });
});

test("a refusal becomes a gentle in-character deflection", async () => {
  const client = fakeClient({ stopReason: "refusal", reply: "" });
  await withServer({ client }, async ({ post }) => {
    const res = await post("/chat", chatBody());
    assert.equal(res.status, 200);
    assert.match(res.body.reply, /baat nahi kar paungi/);
  });
});

test("a failed AI call does not use up a free message", async () => {
  const fail = new Anthropic.APIError(500, { type: "error" }, "boom", new Headers());
  const client = fakeClient({ fail });
  await withServer({ client, freeDailyLimit: 1 }, async ({ post, store }) => {
    const res = await post("/chat", chatBody());
    assert.equal(res.status, 502);
    assert.equal(store.usedToday(DEVICE, new Date()), 0);
  });
});

test("bad requests are rejected", async () => {
  const client = fakeClient();
  await withServer({ client }, async ({ post }) => {
    assert.equal((await post("/chat", chatBody({ deviceId: "short" }))).status, 400);
    assert.equal((await post("/chat", chatBody({ messages: [] }))).status, 400);
    assert.equal(
      (await post("/chat", chatBody({ messages: [{ role: "assistant", text: "hi" }] }))).status,
      400,
    );
    assert.equal(
      (await post("/chat", chatBody({ messages: [{ role: "user", text: "x".repeat(1001) }] }))).status,
      400,
    );
    assert.equal(client.calls.create.length, 0);
  });
});

test("history is trimmed to recent messages starting with the user", async () => {
  const client = fakeClient();
  const messages = [];
  for (let i = 0; i < 20; i++) {
    messages.push({ role: "user", text: `u${i}` }, { role: "assistant", text: `a${i}` });
  }
  messages.push({ role: "user", text: "last" });
  await withServer({ client }, async ({ post }) => {
    assert.equal((await post("/chat", chatBody({ messages }))).status, 200);
    const sent = client.calls.create[0].messages;
    assert.equal(sent.length, 29);
    assert.equal(sent[0].role, "user");
    assert.equal(sent.at(-1).content, "last");
  });
});

test("reports are accepted", async () => {
  await withServer({ client: fakeClient() }, async ({ post }) => {
    const ok = await post("/report", { deviceId: DEVICE, message: "kuch galat", reason: "offensive" });
    assert.deepEqual(ok.body, { ok: true });
    assert.equal((await post("/report", { deviceId: DEVICE, message: "" })).status, 400);
  });
});
