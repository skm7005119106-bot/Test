import { DatabaseSync } from "node:sqlite";

/** The calendar date in India, so the free limit resets at midnight IST. */
export function indiaDate(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(now);
}

/** Daily message counts and user reports, kept in one SQLite file. */
export function openStore(path = ":memory:") {
  const db = new DatabaseSync(path);
  db.exec(`
    CREATE TABLE IF NOT EXISTS usage (
      device_id TEXT NOT NULL,
      day TEXT NOT NULL,
      count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (device_id, day)
    );
    CREATE TABLE IF NOT EXISTS reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL,
      message TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);

  const selectCount = db.prepare("SELECT count FROM usage WHERE device_id = ? AND day = ?");
  const bumpCount = db.prepare(`
    INSERT INTO usage (device_id, day, count) VALUES (?, ?, 1)
    ON CONFLICT (device_id, day) DO UPDATE SET count = count + 1
  `);
  const insertReport = db.prepare(
    "INSERT INTO reports (device_id, message, reason, created_at) VALUES (?, ?, ?, ?)",
  );

  return {
    usedToday(deviceId, now) {
      return selectCount.get(deviceId, indiaDate(now))?.count ?? 0;
    },
    recordMessage(deviceId, now) {
      bumpCount.run(deviceId, indiaDate(now));
    },
    addReport({ deviceId, message, reason }, now = new Date()) {
      insertReport.run(deviceId, message, reason, now.toISOString());
    },
    close() {
      db.close();
    },
  };
}
