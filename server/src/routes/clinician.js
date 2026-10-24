import { Router } from 'express';
import { z } from 'zod';
import { all, get, run, newId } from '../lib/db.js';
import { HttpError, parse, clientNow, notFound } from '../lib/http.js';
import { requireAuth, requireRole } from '../lib/auth.js';
import { initials, regimenDto } from '../lib/dto.js';
import { notify } from '../lib/notify.js';
import { addDays, adherenceFor, buildSlots, missedByPeriod, summarize, weeklyTrend } from '../lib/adherence.js';
import { regimenInput, insertRegimen } from './patient.js';

const r = Router();
r.use(requireAuth, requireRole('clinician'));

function ageFrom(dob) {
  const t = Date.parse(dob);
  if (Number.isNaN(t)) return null;
  return Math.floor((Date.now() - t) / (365.25 * 24 * 3600 * 1000));
}

function ownPatient(clinicianId, patientId) {
  const p = get(
    `SELECT u.id, u.name, u.email, u.phone, u.dob, u.created_at, p.plan, p.note
     FROM users u JOIN patient_profiles p ON p.user_id = u.id
     WHERE u.id = ? AND p.clinician_id = ?`,
    patientId, clinicianId,
  );
  if (!p) throw notFound('Patient not found in your panel');
  return p;
}

function patientSummary(p, now, clinicianId) {
  const { rate, missed } = adherenceFor(p.id, now, 30);
  const regimens = all('SELECT name, strength FROM regimens WHERE patient_id = ? AND active = 1 ORDER BY started', p.id);
  const last = get('SELECT day, logged_time, created_at FROM dose_logs WHERE patient_id = ? ORDER BY created_at DESC LIMIT 1', p.id);
  const unread = get('SELECT COUNT(*) AS n FROM messages WHERE patient_id = ? AND clinician_id = ? AND sender_id = patient_id AND read = 0', p.id, clinicianId);
  return {
    id: p.id, name: p.name, initials: initials(p.name), note: p.note, age: ageFrom(p.dob),
    since: p.created_at, rate, missed,
    regimen: regimens.map((x) => `${x.name} ${x.strength}`.trim()).join(' \u00b7 ') || 'No active regimen',
    lastLog: last ? { day: last.day, time: last.logged_time } : null,
    unreadMessages: unread?.n ?? 0,
  };
}

r.get('/patients', (req, res) => {
  const now = clientNow(req.query);
  const rows = all(
    `SELECT u.id, u.name, u.dob, u.created_at, p.note FROM users u
     JOIN patient_profiles p ON p.user_id = u.id WHERE p.clinician_id = ? ORDER BY u.name`,
    req.user.id,
  );
  const patients = rows.map((p) => patientSummary(p, now, req.user.id));
  const rated = patients.filter((p) => p.rate !== null);
  res.json({
    patients,
    summary: {
      total: patients.length,
      avgAdherence: rated.length ? Math.round(rated.reduce((a, p) => a + p.rate, 0) / rated.length) : null,
      needsAttention: rated.filter((p) => p.rate < 80).length,
    },
  });
});

r.get('/patients/:id', (req, res) => {
  const now = clientNow(req.query);
  const p = ownPatient(req.user.id, req.params.id);
  res.json({
    patient: { ...patientSummary(p, now, req.user.id), email: p.email, phone: p.phone, dob: p.dob },
    regimens: all('SELECT * FROM regimens WHERE patient_id = ? ORDER BY active DESC, started DESC', p.id).map(regimenDto),
    history: all('SELECT id, date, title, detail, place FROM history WHERE patient_id = ? ORDER BY date DESC', p.id),
  });
});

r.post('/patients/:id/regimens', (req, res) => {
  const d = parse(regimenInput, req.body);
  const p = ownPatient(req.user.id, req.params.id);
  const regimen = insertRegimen(p.id, req.user.id, d);
  notify(p.id, 'regimen', `New regimen assigned by ${req.user.name}`, `${regimen.name} added to your plan.`);
  res.status(201).json({ regimen });
});

const historyInput = z.object({
  date: z.string().trim().min(4).max(40),
  title: z.string().trim().min(2).max(120),
  detail: z.string().trim().max(500).optional().default(''),
  place: z.string().trim().max(120).optional().default(''),
});

r.post('/patients/:id/history', (req, res) => {
  const d = parse(historyInput, req.body);
  const p = ownPatient(req.user.id, req.params.id);
  const id = newId();
  run('INSERT INTO history (id, patient_id, date, title, detail, place) VALUES (?,?,?,?,?,?)', id, p.id, d.date, d.title, d.detail, d.place);
  res.status(201).json({ record: { id, ...d } });
});

const linkSchema = z.object({ email: z.string().trim().toLowerCase().pipe(z.email('Enter a valid email address')) });

/** Add an existing patient account to this clinician's panel. */
r.post('/patients/link', (req, res) => {
  const { email } = parse(linkSchema, req.body);
  const p = get("SELECT u.id, p.clinician_id FROM users u JOIN patient_profiles p ON p.user_id = u.id WHERE u.email = ? AND u.role = 'patient'", email);
  if (!p) throw notFound('No patient account found with that email');
  if (p.clinician_id && p.clinician_id !== req.user.id) throw new HttpError(409, 'That patient is already assigned to another clinician');
  run('UPDATE patient_profiles SET clinician_id = ? WHERE user_id = ?', req.user.id, p.id);
  res.status(201).json({ ok: true, patientId: p.id });
});

r.get('/analytics', (req, res) => {
  const now = clientNow(req.query);
  const rows = all(
    'SELECT u.id, u.name FROM users u JOIN patient_profiles p ON p.user_id = u.id WHERE p.clinician_id = ? ORDER BY u.name',
    req.user.id,
  );
  const from56 = addDays(now.day, -55);
  const from30 = addDays(now.day, -29);
  let panel56 = [];
  let panel30 = [];
  const byPatient = rows.map((p) => {
    const s56 = buildSlots(p.id, from56, now.day, now);
    const s30 = s56.filter((s) => s.day >= from30);
    panel56 = panel56.concat(s56);
    panel30 = panel30.concat(s30);
    return { id: p.id, name: p.name, rate: summarize(s30).rate };
  });
  const rated = byPatient.filter((p) => p.rate !== null);
  const totals = summarize(panel30);
  res.json({
    avgAdherence: rated.length ? Math.round(rated.reduce((a, p) => a + p.rate, 0) / rated.length) : null,
    onTrack: rated.filter((p) => p.rate >= 80).length,
    patients: rows.length,
    missed: totals.missed,
    byPatient,
    trend: weeklyTrend(panel56, 8, now.day),
    slips: missedByPeriod(panel30),
  });
});

export default r;
