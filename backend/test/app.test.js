import assert from "node:assert/strict";
import { describe, test } from "node:test";
import Anthropic from "@anthropic-ai/sdk";
import { createApp, purchaseAccountId } from "../src/app.js";
import { openDb } from "../src/db.js";
import { indiaDate, nextStreak, moodLock } from "../src/progress.js";

// Runs every test on SQLite, and also on Postgres when TEST_DATABASE_URL is set.
const databases = [["sqlite", ":memory:"]];
if (process.env.TEST_DATABASE_URL) databases.push(["postgres", process.env.TEST_DATABASE_URL]);

function fakeClaude() {
  const calls = { reply: [], memory: [] };
  const behaviour = { fail: null, refuse: false, facts: ["Pune me rehta hai"], reply: "Aww jaan 💕" };
  return {
    calls,
    behaviour,
    messages: {
      async parse(params) {
        const isMemory = typeof params.system === "string";
        (isMemory ? calls.memory : calls.reply).push(params);
        if (behaviour.fail) throw behaviour.fail;
        if (isMemory) return { stop_reason: "end_turn", parsed_output: { facts: behaviour.facts } };
        if (behaviour.refuse) return { stop_reason: "refusal", parsed_output: null };
        return {
          stop_reason: "end_turn",
          parsed_output: { message: behaviour.reply, suggestions: ["Haan", "  Tum batao  ", "", "Miss kiya", "Extra"] },
        };
      },
    },
  };
}

const fakeGoogle = async (idToken) => {
  const [kind, sub, name] = idToken.split(":");
  if (kind !== "google") throw new Error("bad token");
  return { id: `g_${sub}`, email: `${sub}@example.com`, name };
};

async function harness(dbUrl, { config = {}, verifyPurchase = null, clock } = {}) {
  const db = await openDb(dbUrl);
  // Postgres keeps data between runs: start each test from empty tables.
  if (db.dialect === "postgres") {
    await db.run("TRUNCATE users, sessions, messages, memories, forgotten, usage, reports, purchases RESTART IDENTITY");
  }
  const claude = fakeClaude();
  const time = { now: clock ?? new Date("2026-11-19T10:00:00+05:30") };
  const app = createApp({ db, claude, verifyGoogleToken: fakeGoogle, verifyPurchase, config, now: () => time.now });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, path, { body, token } = {}) => {
    const headers = { "Content-Type": "application/json" };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
    const type = res.headers.get("content-type") || "";
    return { status: res.status, body: type.includes("json") ? await res.json() : await res.text() };
  };
  const signIn = async (sub = "111", name = "Aman") => {
    const res = await call("POST", "/auth/google", { body: { idToken: `google:${sub}:${name}` } });
    assert.equal(res.status, 200);
    return res.body;
  };
  const setUp = async (sub = "111") => {
    const { token } = await signIn(sub);
    await call("PATCH", "/me", { token, body: { name: "Aman", nickname: "Jaan" } });
    return token;
  };
  const close = async () => {
    await app.idle();
    server.close();
    await db.close();
  };
  return { app, db, claude, time, call, signIn, setUp, close };
}

for (const [dialect, url] of databases) {
  describe(`Kayra API (${dialect})`, () => {
    test("Google sign-in creates an account and a session", async () => {
      const h = await harness(url);
      try {
        const res = await h.signIn("111", "Aman");
        assert.equal(res.suggestedName, "Aman");
        assert.equal(res.token.length, 43);
        assert.equal(res.me.profile.name, "");
        assert.equal(res.me.progress.levelName, "Stranger");
        assert.equal(res.me.plus.active, false);
        assert.equal(res.me.purchaseAccountId, purchaseAccountId("g_111"));

        const me = await h.call("GET", "/me", { token: res.token });
        assert.equal(me.status, 200);
        assert.equal(me.body.profile.email, "111@example.com");
      } finally {
        await h.close();
      }
    });

    test("requests without a valid session are rejected", async () => {
      const h = await harness(url);
      try {
        assert.equal((await h.call("GET", "/me")).status, 401);
        assert.equal((await h.call("GET", "/me", { token: "x".repeat(43) })).status, 401);
        const bad = await h.call("POST", "/auth/google", { body: { idToken: "forged:token:value" } });
        assert.equal(bad.status, 401);
      } finally {
        await h.close();
      }
    });

    test("first profile setup adds Kayra's greeting", async () => {
      const h = await harness(url);
      try {
        const { token } = await h.signIn();
        const chatFirst = await h.call("POST", "/chat", { token, body: { text: "hi" } });
        assert.equal(chatFirst.status, 409);

        const res = await h.call("PATCH", "/me", { token, body: { name: "Aman", nickname: "Jaan" } });
        assert.equal(res.status, 200);
        assert.equal(res.body.messages.length, 1);
        assert.match(res.body.messages[0].text, /Hii Jaan!/);

        await h.call("PATCH", "/me", { token, body: { nickname: "Babu" } });
        const me = await h.call("GET", "/me", { token });
        assert.equal(me.body.profile.nickname, "Babu");
        assert.equal(me.body.messages.length, 1);
      } finally {
        await h.close();
      }
    });

    test("chat returns Kayra's reply, suggestions, progress and remaining messages", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        const res = await h.call("POST", "/chat", { token, body: { text: "kya kar rahi ho?" } });
        assert.equal(res.status, 200);
        assert.equal(res.body.reply.text, "Aww jaan 💕");
        assert.equal(res.body.sent.text, "kya kar rahi ho?");
        assert.deepEqual(res.body.suggestions, ["Haan", "Tum batao", "Miss kiya"]);
        assert.equal(res.body.progress.xp, 10);
        assert.equal(res.body.progress.streak, 1);
        assert.deepEqual(res.body.usage, { limit: 30, remaining: 29 });

        const sent = h.claude.calls.reply[0];
        assert.equal(sent.model, "claude-haiku-5-5");
        assert.match(sent.system[0].text, /Tum Kayra ho/);
        assert.match(sent.system[1].text, /naye naye mile/);
        assert.match(sent.system[1].text, /mood sweet/);
        assert.match(sent.system[1].text, /Jaan/);
        // The greeting is Kayra's, so the history sent to Claude starts at the user's message.
        assert.deepEqual(sent.messages, [{ role: "user", content: "kya kar rahi ho?" }]);

        const me = await h.call("GET", "/me", { token });
        assert.deepEqual(me.body.messages.map((m) => m.role), ["assistant", "user", "assistant"]);
      } finally {
        await h.close();
      }
    });

    test("reaching 40 points levels up to Dost", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        let last;
        for (let i = 0; i < 4; i++) last = await h.call("POST", "/chat", { token, body: { text: `msg ${i}` } });
        assert.equal(last.body.levelUp, "Dost");
        assert.equal(last.body.progress.levelName, "Dost");
        assert.equal(last.body.progress.nextAt, 120);
      } finally {
        await h.close();
      }
    });

    test("the free daily limit blocks chat and resets the next India day", async () => {
      const h = await harness(url, { config: { freeDailyLimit: 2 } });
      try {
        const token = await h.setUp();
        assert.equal((await h.call("POST", "/chat", { token, body: { text: "1" } })).status, 200);
        assert.equal((await h.call("POST", "/chat", { token, body: { text: "2" } })).status, 200);
        const blocked = await h.call("POST", "/chat", { token, body: { text: "3" } });
        assert.equal(blocked.status, 429);
        assert.equal(blocked.body.error, "daily_limit");
        assert.equal(h.claude.calls.reply.length, 2);

        h.time.now = new Date("2026-11-20T00:05:00+05:30");
        const next = await h.call("POST", "/chat", { token, body: { text: "4" } });
        assert.equal(next.status, 200);
        assert.equal(next.body.progress.streak, 2);
      } finally {
        await h.close();
      }
    });

    test("a failed AI call keeps the message free and stores nothing", async () => {
      const h = await harness(url, { config: { freeDailyLimit: 1 } });
      try {
        const token = await h.setUp();
        h.claude.behaviour.fail = new Anthropic.APIError(500, { type: "error" }, "boom", new Headers());
        const res = await h.call("POST", "/chat", { token, body: { text: "hello" } });
        assert.equal(res.status, 502);
        const me = await h.call("GET", "/me", { token });
        assert.equal(me.body.messages.length, 1);
        assert.equal(me.body.usage.remaining, 1);
        assert.equal(me.body.progress.xp, 0);
      } finally {
        await h.close();
      }
    });

    test("a refusal becomes a gentle in-character reply", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        h.claude.behaviour.refuse = true;
        const res = await h.call("POST", "/chat", { token, body: { text: "kuch bhi" } });
        assert.equal(res.status, 200);
        assert.match(res.body.reply.text, /baat nahi kar paungi/);
      } finally {
        await h.close();
      }
    });

    test("memories refresh every 8th message, and deleted ones are remembered as forgotten", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        for (let i = 0; i < 8; i++) await h.call("POST", "/chat", { token, body: { text: `msg ${i}` } });
        await h.app.idle();
        assert.equal(h.claude.calls.memory.length, 1);
        assert.match(h.claude.calls.memory[0].system, /Zyada se zyada 20 facts/);

        let me = await h.call("GET", "/me", { token });
        assert.deepEqual(me.body.memory.items.map((m) => m.fact), ["Pune me rehta hai"]);

        const removed = await h.call("DELETE", `/memories/${me.body.memory.items[0].id}`, { token });
        assert.deepEqual(removed.body.items, []);

        for (let i = 0; i < 8; i++) await h.call("POST", "/chat", { token, body: { text: `more ${i}` } });
        await h.app.idle();
        assert.match(h.claude.calls.memory[1].messages[0].content, /bhoolne ko kaha hai:\n- Pune me rehta hai/);

        // Kayra reads memories when replying.
        me = await h.call("GET", "/me", { token });
        assert.equal(me.body.memory.items.length, 1);
        await h.call("POST", "/chat", { token, body: { text: "yaad hai?" } });
        assert.match(h.claude.calls.reply.at(-1).system[1].text, /yaad hai\n- Pune me rehta hai/);
      } finally {
        await h.close();
      }
    });

    test("moods are locked by level and by Kayra Plus", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        assert.equal((await h.call("PATCH", "/me", { token, body: { mood: "funny" } })).status, 200);
        const flirty = await h.call("PATCH", "/me", { token, body: { mood: "flirty" } });
        assert.deepEqual([flirty.status, flirty.body.reason], [403, "level"]);
        const shy = await h.call("PATCH", "/me", { token, body: { mood: "shy" } });
        assert.deepEqual([shy.status, shy.body.reason], [403, "plus"]);
        const unknown = await h.call("PATCH", "/me", { token, body: { mood: "angry" } });
        assert.equal(unknown.status, 403);

        await h.db.run("UPDATE users SET xp = 120 WHERE id = ?", ["g_111"]);
        assert.equal((await h.call("PATCH", "/me", { token, body: { mood: "flirty" } })).status, 200);
        await h.call("POST", "/chat", { token, body: { text: "hi" } });
        assert.match(h.claude.calls.reply.at(-1).system[1].text, /mood flirty/);
        assert.match(h.claude.calls.reply.at(-1).system[1].text, /crush hai/);
      } finally {
        await h.close();
      }
    });

    test("reactions and reports only work on your own Kayra messages", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp("111");
        const other = await h.setUp("222");
        const chat = await h.call("POST", "/chat", { token, body: { text: "hi" } });
        const replyId = chat.body.reply.id;

        assert.equal((await h.call("PUT", `/messages/${replyId}/reaction`, { token, body: { emoji: "❤️" } })).status, 200);
        assert.equal((await h.call("PUT", `/messages/${chat.body.sent.id}/reaction`, { token, body: { emoji: "❤️" } })).status, 404);
        assert.equal((await h.call("PUT", `/messages/${replyId}/reaction`, { token: other, body: { emoji: "😂" } })).status, 404);
        assert.equal((await h.call("PUT", `/messages/${replyId}/reaction`, { token, body: { emoji: "💩" } })).status, 400);
        const me = await h.call("GET", "/me", { token });
        assert.equal(me.body.messages.at(-1).reaction, "❤️");

        assert.equal((await h.call("POST", "/report", { token, body: { messageId: replyId, reason: "galat" } })).status, 200);
        assert.equal((await h.call("POST", "/report", { token: other, body: { messageId: replyId } })).status, 404);
        const reports = (await h.db.all("SELECT text, reason FROM reports")).map((r) => ({ ...r }));
        assert.deepEqual(reports, [{ text: "Aww jaan 💕", reason: "galat" }]);
      } finally {
        await h.close();
      }
    });

    test("Kayra Plus purchases are verified and raise the limits", async () => {
      const expiry = new Date("2026-12-19T10:00:00+05:30").getTime();
      let account = purchaseAccountId("g_111");
      const verifyPurchase = async (token) => {
        if (token === "bad-token-123") throw new Error("not found");
        return { productId: "kayra_plus_monthly", expiry, active: true, state: "SUBSCRIPTION_STATE_ACTIVE", accountId: account };
      };
      const h = await harness(url, { verifyPurchase, config: { freeDailyLimit: 1, plusDailyLimit: 5 } });
      try {
        const token = await h.setUp("111");
        const shy = await h.call("PATCH", "/me", { token, body: { mood: "shy" } });
        assert.equal(shy.status, 403);

        const bad = await h.call("POST", "/billing/google-play", { token, body: { productId: "kayra_plus_monthly", purchaseToken: "bad-token-123" } });
        assert.equal(bad.status, 400);
        const unknown = await h.call("POST", "/billing/google-play", { token, body: { productId: "free_money", purchaseToken: "token-abc-123" } });
        assert.equal(unknown.status, 400);

        const ok = await h.call("POST", "/billing/google-play", { token, body: { productId: "kayra_plus_monthly", purchaseToken: "token-abc-123" } });
        assert.equal(ok.status, 200);
        assert.equal(ok.body.plus.active, true);
        assert.equal(ok.body.plus.until, expiry);
        assert.deepEqual(ok.body.usage, { limit: 5, remaining: 5 });
        assert.equal(ok.body.memory.limit, 40);
        assert.equal((await h.call("PATCH", "/me", { token, body: { mood: "shy" } })).status, 200);

        // The same purchase cannot unlock a second account.
        const other = await h.setUp("222");
        const stolen = await h.call("POST", "/billing/google-play", { token: other, body: { productId: "kayra_plus_monthly", purchaseToken: "token-abc-123" } });
        assert.equal(stolen.status, 409);
        account = purchaseAccountId("g_999");
        const foreign = await h.call("POST", "/billing/google-play", { token: other, body: { productId: "kayra_plus_monthly", purchaseToken: "token-new-456" } });
        assert.equal(foreign.status, 409);

        // Plus ends when the subscription expires.
        h.time.now = new Date("2026-12-20T10:00:00+05:30");
        const later = await h.call("GET", "/me", { token });
        assert.equal(later.body.plus.active, false);
        assert.equal(later.body.usage.limit, 1);
      } finally {
        await h.close();
      }
    });

    test("purchases are refused when billing is not set up", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        const res = await h.call("POST", "/billing/google-play", { token, body: { productId: "kayra_plus_monthly", purchaseToken: "token-abc-123" } });
        assert.equal(res.status, 503);
      } finally {
        await h.close();
      }
    });

    test("clearing chat, signing out and deleting the account", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        await h.call("POST", "/chat", { token, body: { text: "hi" } });
        assert.equal((await h.call("DELETE", "/me/messages", { token })).status, 200);
        let me = await h.call("GET", "/me", { token });
        assert.equal(me.body.messages.length, 0);
        assert.equal(me.body.progress.xp, 10);

        const second = (await h.signIn()).token;
        assert.equal((await h.call("POST", "/auth/sign-out", { token })).status, 200);
        assert.equal((await h.call("GET", "/me", { token })).status, 401);
        assert.equal((await h.call("GET", "/me", { token: second })).status, 200);

        assert.equal((await h.call("DELETE", "/me", { token: second })).status, 200);
        assert.equal((await h.call("GET", "/me", { token: second })).status, 401);
        const fresh = await h.signIn();
        assert.equal(fresh.me.profile.name, "");
        assert.equal(fresh.me.progress.xp, 0);
      } finally {
        await h.close();
      }
    });

    test("bad input is rejected without calling the AI", async () => {
      const h = await harness(url);
      try {
        const token = await h.setUp();
        assert.equal((await h.call("POST", "/chat", { token, body: { text: "" } })).status, 400);
        assert.equal((await h.call("POST", "/chat", { token, body: { text: "x".repeat(1001) } })).status, 400);
        assert.equal((await h.call("PATCH", "/me", { token, body: { name: "" } })).status, 400);
        assert.equal(h.claude.calls.reply.length, 0);
      } finally {
        await h.close();
      }
    });

    test("privacy policy and account deletion pages are public", async () => {
      const h = await harness(url, { config: { supportEmail: "help@example.com" } });
      try {
        const privacy = await h.call("GET", "/privacy");
        assert.equal(privacy.status, 200);
        assert.match(privacy.body, /Kayra Privacy Policy/);
        assert.match(privacy.body, /help@example.com/);
        const del = await h.call("GET", "/delete-account");
        assert.match(del.body, /Delete account/);
      } finally {
        await h.close();
      }
    });
  });
}

test("streaks count consecutive India days", () => {
  const day = (iso) => new Date(iso);
  assert.deepEqual(nextStreak({ streak: 0, lastDay: "" }, day("2026-11-19T12:00:00+05:30")), { streak: 1, lastDay: "2026-11-19" });
  assert.deepEqual(nextStreak({ streak: 3, lastDay: "2026-11-18" }, day("2026-11-19T00:10:00+05:30")), { streak: 4, lastDay: "2026-11-19" });
  assert.deepEqual(nextStreak({ streak: 3, lastDay: "2026-11-19" }, day("2026-11-19T23:00:00+05:30")), { streak: 3, lastDay: "2026-11-19" });
  assert.deepEqual(nextStreak({ streak: 9, lastDay: "2026-11-10" }, day("2026-11-19T12:00:00+05:30")), { streak: 1, lastDay: "2026-11-19" });
  assert.equal(indiaDate(new Date("2026-11-19T19:00:00Z")), "2026-11-20");
});

test("mood locks", () => {
  assert.equal(moodLock("sweet", { xp: 0, plus: false }), "");
  assert.equal(moodLock("flirty", { xp: 119, plus: true }), "level");
  assert.equal(moodLock("flirty", { xp: 120, plus: false }), "");
  assert.equal(moodLock("shy", { xp: 999, plus: false }), "plus");
});
