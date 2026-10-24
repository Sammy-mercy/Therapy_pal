import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const dbPath = process.env.DB_PATH || './data/therapy_pal.db';
fs.mkdirSync(path.dirname(path.resolve(dbPath)), { recursive: true });

export const db = new DatabaseSync(dbPath);
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  role TEXT NOT NULL CHECK (role IN ('patient','clinician')),
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  dob TEXT NOT NULL DEFAULT '',
  prefs TEXT NOT NULL DEFAULT '{"doseReminders":true,"missedDose":true,"clinicianMessages":true,"weeklySummary":false}',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS clinician_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  npi TEXT NOT NULL DEFAULT '',
  specialization TEXT NOT NULL DEFAULT '',
  license TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS clinics (
  id TEXT PRIMARY KEY,
  clinician_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  patients INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS patient_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  clinician_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  plan TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS regimens (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  prescriber_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  strength TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL CHECK (type IN ('medication','therapy')),
  active INTEGER NOT NULL DEFAULT 1,
  schedule TEXT NOT NULL DEFAULT '',
  times TEXT NOT NULL DEFAULT '[]',
  started TEXT NOT NULL,
  start_time TEXT NOT NULL DEFAULT '00:00',
  note TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS dose_logs (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  regimen_id TEXT NOT NULL REFERENCES regimens(id) ON DELETE CASCADE,
  day TEXT NOT NULL,
  slot TEXT NOT NULL,
  logged_time TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (regimen_id, day, slot)
);
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('reminder','regimen','message','alert')),
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  read INTEGER NOT NULL DEFAULT 0,
  dedupe_key TEXT UNIQUE,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  clinician_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS history (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  title TEXT NOT NULL,
  detail TEXT NOT NULL DEFAULT '',
  place TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_regimens_patient ON regimens(patient_id);
CREATE INDEX IF NOT EXISTS idx_logs_patient_day ON dose_logs(patient_id, day);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_pair ON messages(patient_id, clinician_id, created_at);
`);

export const newId = () => crypto.randomUUID();
export const nowIso = () => new Date().toISOString();
export const all = (sql, ...p) => db.prepare(sql).all(...p).map((r) => ({ ...r }));
export const get = (sql, ...p) => {
  const r = db.prepare(sql).get(...p);
  return r ? { ...r } : undefined;
};
export const run = (sql, ...p) => db.prepare(sql).run(...p);

export function tx(fn) {
  db.exec('BEGIN');
  try {
    const out = fn();
    db.exec('COMMIT');
    return out;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}
