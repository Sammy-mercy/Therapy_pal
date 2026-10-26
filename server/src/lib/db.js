import { createClient } from '@libsql/client';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

/**
 * Database connection.
 *  - Production / Vercel: set TURSO_DATABASE_URL (+ TURSO_AUTH_TOKEN) to use a hosted Turso database.
 *  - Local development: leave them empty and a SQLite file at DB_PATH is used.
 */
const remoteUrl = process.env.TURSO_DATABASE_URL;
const isProd = process.env.NODE_ENV === 'production';

if (!remoteUrl && isProd) {
  // A local file would be thrown away on Vercel, so refuse instead of silently losing data.
  throw new Error('TURSO_DATABASE_URL is not set. Production needs a hosted database (see docs/DEPLOYMENT.md).');
}

let url = remoteUrl;
if (!url) {
  const file = process.env.DB_PATH || './data/therapy_pal.db';
  fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  url = `file:${file}`;
}

export const db = createClient({ url, authToken: process.env.TURSO_AUTH_TOKEN || undefined });
export const isRemoteDb = Boolean(remoteUrl);

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    role TEXT NOT NULL CHECK (role IN ('patient','clinician')),
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL DEFAULT '',
    dob TEXT NOT NULL DEFAULT '',
    prefs TEXT NOT NULL DEFAULT '{"doseReminders":true,"missedDose":true,"clinicianMessages":true,"weeklySummary":false}',
    created_at TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS clinician_profiles (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    npi TEXT NOT NULL DEFAULT '',
    specialization TEXT NOT NULL DEFAULT '',
    license TEXT NOT NULL DEFAULT ''
  )`,
  `CREATE TABLE IF NOT EXISTS clinics (
    id TEXT PRIMARY KEY,
    clinician_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    patients INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS patient_profiles (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    clinician_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    plan TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT ''
  )`,
  `CREATE TABLE IF NOT EXISTS regimens (
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
  )`,
  `CREATE TABLE IF NOT EXISTS dose_logs (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    regimen_id TEXT NOT NULL REFERENCES regimens(id) ON DELETE CASCADE,
    day TEXT NOT NULL,
    slot TEXT NOT NULL,
    logged_time TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (regimen_id, day, slot)
  )`,
  `CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('reminder','regimen','message','alert')),
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    read INTEGER NOT NULL DEFAULT 0,
    dedupe_key TEXT UNIQUE,
    created_at TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    clinician_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS history (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    title TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    place TEXT NOT NULL DEFAULT ''
  )`,
  'CREATE INDEX IF NOT EXISTS idx_regimens_patient ON regimens(patient_id)',
  'CREATE INDEX IF NOT EXISTS idx_logs_patient_day ON dose_logs(patient_id, day)',
  'CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at)',
  'CREATE INDEX IF NOT EXISTS idx_msg_pair ON messages(patient_id, clinician_id, created_at)',
];

let readyPromise;

/** Creates any missing tables once per server instance. Safe to call on every request. */
export function ready() {
  if (!readyPromise) {
    readyPromise = (async () => {
      if (!isRemoteDb) await db.execute('PRAGMA foreign_keys = ON');
      await db.batch(SCHEMA, 'write');
    })().catch((err) => {
      readyPromise = undefined; // try again on the next request
      throw err;
    });
  }
  return readyPromise;
}

const clean = (args) => args.map((v) => (v === undefined ? null : v));
const toObject = (res, row) => Object.fromEntries(res.columns.map((c, i) => [c, row[i]]));

/** All matching rows as plain objects. */
export async function all(sql, ...args) {
  const res = await db.execute({ sql, args: clean(args) });
  return res.rows.map((r) => toObject(res, r));
}

/** The first matching row, or undefined. */
export async function get(sql, ...args) {
  return (await all(sql, ...args))[0];
}

/** Runs one write. Returns how many rows changed. */
export async function run(sql, ...args) {
  const res = await db.execute({ sql, args: clean(args) });
  return { changes: Number(res.rowsAffected) };
}

/** Runs several writes as one all-or-nothing group. Build statements with `stmt()`. */
export async function batch(statements) {
  if (statements.length) await db.batch(statements, 'write');
}

export const stmt = (sql, ...args) => ({ sql, args: clean(args) });

export const newId = () => crypto.randomUUID();
export const nowIso = () => new Date().toISOString();
