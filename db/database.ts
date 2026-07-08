import * as SQLite from 'expo-sqlite';

let _db: SQLite.SQLiteDatabase | null = null;

export async function getDatabase(): Promise<SQLite.SQLiteDatabase> {
  if (_db) return _db;
  _db = await SQLite.openDatabaseAsync('putttrack.db');
  await initSchema(_db);
  return _db;
}

async function initSchema(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS putters (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS rounds (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      course_name TEXT    DEFAULT '',
      putter_id   INTEGER REFERENCES putters(id),
      stimp       REAL    NOT NULL DEFAULT 10,
      wind        TEXT    NOT NULL DEFAULT 'none',
      weather     TEXT    NOT NULL DEFAULT 'warm',
      date        TEXT    DEFAULT (datetime('now')),
      is_complete INTEGER DEFAULT 0,
      hole_count  INTEGER NOT NULL DEFAULT 18,
      notes       TEXT    DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS putts (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      round_id       INTEGER NOT NULL REFERENCES rounds(id),
      hole_number    INTEGER NOT NULL DEFAULT 1,
      putt_number    INTEGER NOT NULL DEFAULT 1,
      distance_m     REAL    NOT NULL DEFAULT 3.0,
      side_slope_pct REAL    NOT NULL DEFAULT 0,
      hill_slope_pct REAL    NOT NULL DEFAULT 0,
      double_break   TEXT,
      result         TEXT    NOT NULL DEFAULT 'holed',
      lip_out        INTEGER NOT NULL DEFAULT 0,
      miss_read      INTEGER NOT NULL DEFAULT 0,
      bad_strike     INTEGER NOT NULL DEFAULT 0,
      sg_baseline    REAL    DEFAULT 0,
      sg_actual      REAL    DEFAULT 0,
      created_at     TEXT    DEFAULT (datetime('now'))
    );

    INSERT OR IGNORE INTO settings (key, value) VALUES
      ('units',   'metric'),
      ('haptics', 'true');
  `);

  // Migrations — add new columns to existing databases
  await runMigrations(db);
}

async function runMigrations(db: SQLite.SQLiteDatabase): Promise<void> {
  const columns = await db.getAllAsync<{ name: string }>(
    `PRAGMA table_info(putts)`
  );
  const colNames = columns.map((c) => c.name);

  if (!colNames.includes('lip_out')) {
    await db.execAsync(`ALTER TABLE putts ADD COLUMN lip_out INTEGER NOT NULL DEFAULT 0`);
  }
  if (!colNames.includes('miss_read')) {
    await db.execAsync(`ALTER TABLE putts ADD COLUMN miss_read INTEGER NOT NULL DEFAULT 0`);
  }
  if (!colNames.includes('bad_strike')) {
    await db.execAsync(`ALTER TABLE putts ADD COLUMN bad_strike INTEGER NOT NULL DEFAULT 0`);
  }

  const roundColumns = await db.getAllAsync<{ name: string }>(
    `PRAGMA table_info(rounds)`
  );
  const roundColNames = roundColumns.map((c) => c.name);

  if (!roundColNames.includes('hole_count')) {
    await db.execAsync(`ALTER TABLE rounds ADD COLUMN hole_count INTEGER NOT NULL DEFAULT 18`);
  }
}
