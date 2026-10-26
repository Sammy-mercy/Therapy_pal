import { get, run, batch, stmt, newId, nowIso } from './db.js';
import { buildSlots } from './adherence.js';

const PREF_FOR_KIND = { reminder: 'doseReminders', alert: 'missedDose', message: 'clinicianMessages' };

const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

async function wants(userId, kind) {
  const user = await get('SELECT prefs FROM users WHERE id = ?', userId);
  if (!user) return false;
  const prefKey = PREF_FOR_KIND[kind];
  if (!prefKey) return true;
  try {
    return JSON.parse(user.prefs)[prefKey] !== false;
  } catch {
    return true;
  }
}

const insertSql = `INSERT OR IGNORE INTO notifications (id, user_id, kind, title, body, dedupe_key, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?)`;

/** Create a notification, respecting the recipient's preferences. Duplicate keys are ignored. */
export async function notify(userId, kind, title, body = '', dedupeKey = null) {
  if (!(await wants(userId, kind))) return;
  await run(insertSql, newId(), userId, kind, title, body, dedupeKey, nowIso());
}

/**
 * v1 has no push service, so reminders and missed-dose alerts are produced
 * when the patient's app fetches notifications (keyed so each is created once).
 */
export async function generateDoseNotifications(patientId, now) {
  const [slots, user] = await Promise.all([
    buildSlots(patientId, now.day, now.day, now),
    get('SELECT prefs FROM users WHERE id = ?', patientId),
  ]);
  if (!user) return;
  let prefs = {};
  try {
    prefs = JSON.parse(user.prefs);
  } catch { /* defaults */ }

  const nowMin = toMin(now.time);
  const created = nowIso();
  const rows = [];
  for (const s of slots) {
    if (s.status === 'upcoming' && toMin(s.slot) - nowMin <= 30 && prefs.doseReminders !== false) {
      const mins = toMin(s.slot) - nowMin;
      rows.push(['reminder', `Take ${s.name} in ${mins} min`, `Scheduled dose at ${s.slot}.`, `rem:${s.regimenId}:${s.day}:${s.slot}`]);
    } else if (s.status === 'due' && prefs.doseReminders !== false) {
      rows.push(['reminder', `Time to take ${s.name}`, `Scheduled dose at ${s.slot}.`, `due:${s.regimenId}:${s.day}:${s.slot}`]);
    } else if (s.status === 'missed' && prefs.missedDose !== false) {
      rows.push(['alert', `Missed dose: ${s.label}`, `The ${s.slot} dose was not logged.`, `miss:${s.regimenId}:${s.day}:${s.slot}`]);
    }
  }
  // One round trip for all of them.
  await batch(rows.map(([kind, title, body, key]) => stmt(insertSql, newId(), patientId, kind, title, body, key, created)));
}
