import { get, run, newId, nowIso } from './db.js';
import { buildSlots } from './adherence.js';

const PREF_FOR_KIND = { reminder: 'doseReminders', alert: 'missedDose', message: 'clinicianMessages' };

const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

/** Create a notification, respecting the recipient's preferences. Duplicate keys are ignored. */
export function notify(userId, kind, title, body = '', dedupeKey = null) {
  const user = get('SELECT prefs FROM users WHERE id = ?', userId);
  if (!user) return;
  const prefKey = PREF_FOR_KIND[kind];
  if (prefKey) {
    try {
      if (JSON.parse(user.prefs)[prefKey] === false) return;
    } catch { /* fall through to sending */ }
  }
  run(
    `INSERT OR IGNORE INTO notifications (id, user_id, kind, title, body, dedupe_key, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    newId(), userId, kind, title, body, dedupeKey, nowIso(),
  );
}

/**
 * v1 has no push service, so reminders and missed-dose alerts are produced
 * when the patient's app fetches notifications (keyed so each is created once).
 */
export function generateDoseNotifications(patientId, now) {
  const slots = buildSlots(patientId, now.day, now.day, now);
  const nowMin = toMin(now.time);
  for (const s of slots) {
    if (s.status === 'upcoming' && toMin(s.slot) - nowMin <= 30) {
      const mins = toMin(s.slot) - nowMin;
      notify(patientId, 'reminder', `Take ${s.name} in ${mins} min`, `Scheduled dose at ${s.slot}.`, `rem:${s.regimenId}:${s.day}:${s.slot}`);
    } else if (s.status === 'due') {
      notify(patientId, 'reminder', `Time to take ${s.name}`, `Scheduled dose at ${s.slot}.`, `due:${s.regimenId}:${s.day}:${s.slot}`);
    } else if (s.status === 'missed') {
      notify(patientId, 'alert', `Missed dose: ${s.label}`, `The ${s.slot} dose was not logged.`, `miss:${s.regimenId}:${s.day}:${s.slot}`);
    }
  }
}
