// A small database layer that runs the same SQL on SQLite (local use and
// tests) and Postgres (production). Write queries with `?` placeholders.

const AUTO_ID = {
  sqlite: "INTEGER PRIMARY KEY AUTOINCREMENT",
  postgres: "BIGSERIAL PRIMARY KEY",
};

const SCHEMA = (id) => `
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL DEFAULT '',
    name TEXT NOT NULL DEFAULT '',
    nickname TEXT NOT NULL DEFAULT '',
    mood TEXT NOT NULL DEFAULT 'sweet',
    xp INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    last_day TEXT NOT NULL DEFAULT '',
    message_count INTEGER NOT NULL DEFAULT 0,
    plus_until BIGINT NOT NULL DEFAULT 0,
    plus_product TEXT NOT NULL DEFAULT '',
    created_at BIGINT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created_at BIGINT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id);
  CREATE TABLE IF NOT EXISTS messages (
    id ${id},
    user_id TEXT NOT NULL,
    role TEXT NOT NULL,
    text TEXT NOT NULL,
    reaction TEXT,
    created_at BIGINT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS messages_user ON messages (user_id, id);
  CREATE TABLE IF NOT EXISTS memories (
    id ${id},
    user_id TEXT NOT NULL,
    fact TEXT NOT NULL,
    created_at BIGINT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS memories_user ON memories (user_id, id);
  CREATE TABLE IF NOT EXISTS forgotten (
    id ${id},
    user_id TEXT NOT NULL,
    fact TEXT NOT NULL,
    created_at BIGINT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS forgotten_user ON forgotten (user_id, id);
  CREATE TABLE IF NOT EXISTS usage (
    user_id TEXT NOT NULL,
    day TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
  );
  CREATE TABLE IF NOT EXISTS reports (
    id ${id},
    user_id TEXT NOT NULL,
    message_id BIGINT,
    text TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at BIGINT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS purchases (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    expiry BIGINT NOT NULL,
    state TEXT NOT NULL,
    updated_at BIGINT NOT NULL
  );
`;

async function openSqlite(path) {
  const { DatabaseSync } = await import("node:sqlite");
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;");
  db.exec(SCHEMA(AUTO_ID.sqlite));
  const prepared = new Map();
  const statement = (sql) => {
    if (!prepared.has(sql)) prepared.set(sql, db.prepare(sql));
    return prepared.get(sql);
  };
  return {
    dialect: "sqlite",
    async all(sql, params = []) {
      return statement(sql).all(...params);
    },
    async get(sql, params = []) {
      return statement(sql).get(...params);
    },
    async run(sql, params = []) {
      return statement(sql).run(...params);
    },
    async close() {
      db.close();
    },
  };
}

async function openPostgres(url) {
  const { default: pg } = await import("pg");
  // BIGINT and COUNT(*) come back as strings by default; every value here fits in a JS number.
  pg.types.setTypeParser(20, (value) => Number(value));
  const local = /@(localhost|127\.0\.0\.1)[:/]/.test(url);
  const pool = new pg.Pool({
    connectionString: url,
    ssl: local ? false : { rejectUnauthorized: false },
    max: 5,
  });
  const toPg = (sql) => {
    let n = 0;
    return sql.replace(/\?/g, () => `$${++n}`);
  };
  await pool.query(SCHEMA(AUTO_ID.postgres));
  return {
    dialect: "postgres",
    async all(sql, params = []) {
      return (await pool.query(toPg(sql), params)).rows;
    },
    async get(sql, params = []) {
      return (await pool.query(toPg(sql), params)).rows[0];
    },
    async run(sql, params = []) {
      return pool.query(toPg(sql), params);
    },
    async close() {
      await pool.end();
    },
  };
}

/** Postgres when given a postgres:// URL, otherwise SQLite at that path (default: in memory). */
export async function openDb(url) {
  if (url && /^postgres(ql)?:\/\//.test(url)) return openPostgres(url);
  return openSqlite(url || ":memory:");
}
