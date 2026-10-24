import { Router } from 'express';
import { z } from 'zod';
import { all, get, run, newId, nowIso } from '../lib/db.js';
import { HttpError, parse, clientNow, dayStr, timeStr, notFound } from '../lib/http.js';
import { requireAuth, requireRole } from '../lib/auth.js';
import { regimenDto } from '../lib/dto.js';
import { addDays, adherenceFor, buildSlots, missedByPeriod, streakDays, summarize, weeklyTrend } from '../lib/adherence.js';

const r = Router();
r.use(requireAuth, requireRole('patient'));

r.get('/regimens', (req, res) => {
  const rows = all('SELECT * FROM regimens WHERE patient_id = ? ORDER BY active DESC, started DESC', req.user.id);
  res.json({ regimens: rows.map(regimenDto) });
});

export const regimenInput = z.object({
  name: z.string().trim().min(2, 'Enter a name').max(80),
  strength: z.string().trim().max(60).optional().default(''),
  type: z.enum(['medication', 'therapy']),
  schedule: z.string().trim().max(120).optional().default(''),
  times: z.array(timeStr).min(1, 'Add at least one time').max(8),
  note: z.string().trim().max(400).optional().default(''),
  day: dayStr.optional(),
  time: timeStr.optional(),
});

/** Insert a regimen. Slots earlier than "now" on the start day are not counted as missed. */
export function insertRegimen(patientId, prescriberId, d) {
  const now = clientNow(d);
  const id = newId();
  const times = [...new Set(d.times)].sort();
  run(
    `INSERT INTO regimens (id, patient_id, prescriber_id, name, strength, type, active, schedule, times, started, start_time, note)
     VALUES (?,?,?,?,?,?,1,?,?,?,?,?)`,
    id, patientId, prescriberId, d.name, d.strength, d.type,
    d.schedule || `${times.length} time${times.length === 1 ? '' : 's'} daily`,
    JSON.stringify(times), now.day, now.time, d.note,
  );
  return regimenDto(get('SELECT * FROM regimens WHERE id = ?', id));
}

r.post('/regimens', (req, res) => {
  const d = parse(regimenInput, req.body);
  res.status(201).json({ regimen: insertRegimen(req.user.id, null, d) });
});

const patchSchema = z.object({ active: z.boolean().optional(), note: z.string().trim().max(400).optional() });

r.patch('/regimens/:id', (req, res) => {
  const d = parse(patchSchema, req.body);
  const cur = get('SELECT * FROM regimens WHERE id = ? AND patient_id = ?', req.params.id, req.user.id);
  if (!cur) throw notFound('Regimen not found');
  run('UPDATE regimens SET active = ?, note = ? WHERE id = ?', d.active === undefined ? cur.active : d.active ? 1 : 0, d.note ?? cur.note, cur.id);
  res.json({ regimen: regimenDto(get('SELECT * FROM regimens WHERE id = ?', cur.id)) });
});

r.get('/today', (req, res) => {
  const now = clientNow(req.query);
  const doses = buildSlots(req.user.id, now.day, now.day, now);
  const taken = doses.filter((s) => s.status === 'taken').length;
  const next = doses.find((s) => s.status === 'due' || s.status === 'upcoming') || null;
  res.json({ day: now.day, doses, taken, total: doses.length, next });
});

const doseSchema = z.object({
  regimenId: z.string().min(1),
  slot: timeStr.optional(),
  day: dayStr.optional(),
  time: timeStr.optional(),
});

r.post('/doses', (req, res) => {
  const d = parse(doseSchema, req.body);
  const now = clientNow(d);
  const reg = get('SELECT * FROM regimens WHERE id = ? AND patient_id = ? AND active = 1', d.regimenId, req.user.id);
  if (!reg) throw notFound('Regimen not found or paused');

  const today = buildSlots(req.user.id, now.day, now.day, now).filter((s) => s.regimenId === reg.id);
  let slot = d.slot;
  if (slot) {
    if (!today.some((s) => s.slot === slot)) throw new HttpError(400, 'That time is not on this regimen for today');
  } else {
    const open = today.filter((s) => s.status !== 'taken');
    // Prefer a dose that is due/missed now, otherwise the next upcoming one.
    const pick = open.find((s) => s.status === 'due') || open.find((s) => s.status === 'missed') || open[0];
    if (!pick) throw new HttpError(409, "All of today's doses for this item are already logged");
    slot = pick.slot;
  }
  try {
    run(
      'INSERT INTO dose_logs (id, patient_id, regimen_id, day, slot, logged_time, created_at) VALUES (?,?,?,?,?,?,?)',
      newId(), req.user.id, reg.id, now.day, slot, now.time, nowIso(),
    );
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) throw new HttpError(409, 'That dose is already logged');
    throw e;
  }
  res.status(201).json({ ok: true, slot, loggedTime: now.time });
});

r.get('/logs', (req, res) => {
  const now = clientNow(req.query);
  const slots = buildSlots(req.user.id, addDays(now.day, -13), now.day, now)
    .filter((s) => s.status === 'taken' || s.status === 'missed')
    .sort((a, b) => (a.day + (a.loggedTime || a.slot) < b.day + (b.loggedTime || b.slot) ? 1 : -1));
  res.json({ logs: slots.map((s) => ({ day: s.day, label: s.label, time: s.loggedTime || s.slot, status: s.status })) });
});

r.get('/adherence', (req, res) => {
  const now = clientNow(req.query);
  const { slots, taken, missed, scheduled, rate } = adherenceFor(req.user.id, now, 30);
  const todayStats = summarize(slots.filter((s) => s.day === now.day));
  res.json({
    rate, taken, missed, scheduled,
    streak: streakDays(slots, now.day),
    dosesToday: buildSlots(req.user.id, now.day, now.day, now).length,
    weekly: weeklyTrend(slots, 6, now.day),
    slips: missedByPeriod(slots),
    todayTaken: todayStats.taken,
  });
});

r.get('/history', (req, res) => {
  res.json({ history: all('SELECT id, date, title, detail, place FROM history WHERE patient_id = ? ORDER BY date DESC', req.user.id) });
});

export default r;
