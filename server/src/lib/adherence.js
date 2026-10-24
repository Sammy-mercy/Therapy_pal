import { all } from './db.js';

/** A scheduled dose with no log becomes "missed" this many minutes after its slot. */
export const MISSED_AFTER_MIN = 180;

const toMin = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));

export function addDays(day, n) {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function eachDay(from, to) {
  const out = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

/**
 * Expand every active regimen into concrete dose slots for [fromDay, toDay]
 * and resolve each to taken | missed | due | upcoming using the client's "now".
 */
export function buildSlots(patientId, fromDay, toDay, now) {
  const regimens = all('SELECT * FROM regimens WHERE patient_id = ? AND active = 1', patientId);
  const logs = all(
    'SELECT regimen_id, day, slot, logged_time FROM dose_logs WHERE patient_id = ? AND day BETWEEN ? AND ?',
    patientId, fromDay, toDay,
  );
  const logged = new Map(logs.map((l) => [`${l.regimen_id}|${l.day}|${l.slot}`, l.logged_time]));
  const nowMin = toMin(now.time);
  const slots = [];

  for (const r of regimens) {
    const times = JSON.parse(r.times);
    for (const day of eachDay(fromDay < r.started ? r.started : fromDay, toDay)) {
      if (day > now.day) break;
      for (const slot of times) {
        if (day === r.started && slot < (r.start_time || '00:00')) continue;
        const loggedTime = logged.get(`${r.id}|${day}|${slot}`);
        let status;
        if (loggedTime) status = 'taken';
        else if (day < now.day) status = 'missed';
        else if (toMin(slot) + MISSED_AFTER_MIN <= nowMin) status = 'missed';
        else if (toMin(slot) <= nowMin) status = 'due';
        else status = 'upcoming';
        slots.push({
          regimenId: r.id, name: r.name, strength: r.strength, type: r.type,
          label: `${r.name} ${r.strength}`.trim(), day, slot, status, loggedTime: loggedTime || null,
        });
      }
    }
  }
  return slots.sort((a, b) => (a.day + a.slot < b.day + b.slot ? -1 : 1));
}

export function summarize(slots) {
  const taken = slots.filter((s) => s.status === 'taken').length;
  const missed = slots.filter((s) => s.status === 'missed').length;
  const resolved = taken + missed;
  return { taken, missed, scheduled: resolved, rate: resolved ? Math.round((taken / resolved) * 100) : null };
}

const PERIODS = [
  { key: 'morning', label: 'Morning 6\u201311 AM', from: 360, to: 660 },
  { key: 'midday', label: 'Midday 11 AM\u20134 PM', from: 660, to: 960 },
  { key: 'evening', label: 'Evening 4\u20139 PM', from: 960, to: 1260 },
  { key: 'night', label: 'Night 9 PM\u20136 AM', from: 1260, to: 1800 },
];

export function missedByPeriod(slots) {
  const missed = slots.filter((s) => s.status === 'missed');
  return PERIODS.map((p) => ({
    key: p.key,
    label: p.label,
    missed: missed.filter((s) => {
      let m = toMin(s.slot);
      if (m < 360) m += 1440;
      return m >= p.from && m < p.to;
    }).length,
  }));
}

/** Weekly adherence for the last `weeks` weeks (oldest first) ending at now.day. */
export function weeklyTrend(slots, weeks, nowDay) {
  const out = [];
  for (let w = weeks - 1; w >= 0; w--) {
    const end = addDays(nowDay, -7 * w);
    const start = addDays(end, -6);
    out.push(summarize(slots.filter((s) => s.day >= start && s.day <= end)).rate);
  }
  return out;
}

/** Consecutive days (ending today) with at least one taken dose and no misses. */
export function streakDays(slots, nowDay) {
  let streak = 0;
  for (let d = nowDay; ; d = addDays(d, -1)) {
    const day = slots.filter((s) => s.day === d);
    if (!day.length) break;
    if (day.some((s) => s.status === 'missed')) break;
    if (day.some((s) => s.status === 'taken')) streak++;
    else if (d !== nowDay) break;
  }
  return streak;
}

export function adherenceFor(patientId, now, days = 30) {
  const from = addDays(now.day, -(days - 1));
  const slots = buildSlots(patientId, from, now.day, now);
  return { slots, ...summarize(slots) };
}
