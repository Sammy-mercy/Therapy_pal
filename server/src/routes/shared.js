import { Router } from 'express';
import { z } from 'zod';
import { all, get, run, newId, nowIso } from '../lib/db.js';
import { parse, clientNow, notFound } from '../lib/http.js';
import { requireAuth } from '../lib/auth.js';
import { initials } from '../lib/dto.js';
import { generateDoseNotifications, notify } from '../lib/notify.js';

const r = Router();
r.use(requireAuth);

/* ------------------------------------------------------------ notifications */

const notificationDto = (n) => ({ id: n.id, kind: n.kind, title: n.title, body: n.body, read: !!n.read, createdAt: n.created_at });

r.get('/notifications', async (req, res) => {
  if (req.user.role === 'patient') await generateDoseNotifications(req.user.id, clientNow(req.query));
  const rows = await all('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 60', req.user.id);
  res.json({ notifications: rows.map(notificationDto), unread: rows.filter((n) => !n.read).length });
});

r.post('/notifications/read-all', async (req, res) => {
  await run('UPDATE notifications SET read = 1 WHERE user_id = ?', req.user.id);
  res.json({ ok: true });
});

r.post('/notifications/:id/read', async (req, res) => {
  const out = await run('UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?', req.params.id, req.user.id);
  if (!out.changes) throw notFound('Notification not found');
  res.json({ ok: true });
});

/* ----------------------------------------------------------------- messages */

/** Work out which patient/clinician pair a request refers to and check access. */
async function resolvePair(user, patientId) {
  if (user.role === 'patient') {
    const p = await get('SELECT clinician_id FROM patient_profiles WHERE user_id = ?', user.id);
    if (!p?.clinician_id) throw notFound('You are not linked to a clinician yet');
    return { patientId: user.id, clinicianId: p.clinician_id };
  }
  const p = await get('SELECT user_id FROM patient_profiles WHERE user_id = ? AND clinician_id = ?', patientId, user.id);
  if (!p) throw notFound('Patient not found in your panel');
  return { patientId: p.user_id, clinicianId: user.id };
}

const messageDto = (m, viewerId) => ({ id: m.id, from: m.sender_id === viewerId ? 'me' : 'them', text: m.text, createdAt: m.created_at });

async function threadSummary(patientId, clinicianId, viewer, displayName) {
  const [last, unread] = await Promise.all([
    get('SELECT * FROM messages WHERE patient_id = ? AND clinician_id = ? ORDER BY created_at DESC LIMIT 1', patientId, clinicianId),
    get(
      'SELECT COUNT(*) AS n FROM messages WHERE patient_id = ? AND clinician_id = ? AND sender_id != ? AND read = 0',
      patientId, clinicianId, viewer.id,
    ),
  ]);
  return {
    patientId, name: displayName, initials: initials(displayName), unread: unread.n,
    last: last ? messageDto(last, viewer.id) : null,
  };
}

r.get('/messages/threads', async (req, res) => {
  let threads;
  if (req.user.role === 'patient') {
    const p = await get('SELECT clinician_id FROM patient_profiles WHERE user_id = ?', req.user.id);
    const c = p?.clinician_id ? await get('SELECT id, name FROM users WHERE id = ?', p.clinician_id) : null;
    threads = c ? [await threadSummary(req.user.id, c.id, req.user, c.name)] : [];
  } else {
    const patients = await all(
      'SELECT u.id, u.name FROM users u JOIN patient_profiles p ON p.user_id = u.id WHERE p.clinician_id = ?',
      req.user.id,
    );
    threads = await Promise.all(patients.map((p) => threadSummary(p.id, req.user.id, req.user, p.name)));
  }
  threads.sort((a, b) => (b.last?.createdAt || '').localeCompare(a.last?.createdAt || ''));
  res.json({ threads, unread: threads.reduce((n, t) => n + t.unread, 0) });
});

r.get('/messages/threads/:patientId', async (req, res) => {
  const pair = await resolvePair(req.user, req.params.patientId);
  await run(
    'UPDATE messages SET read = 1 WHERE patient_id = ? AND clinician_id = ? AND sender_id != ?',
    pair.patientId, pair.clinicianId, req.user.id,
  );
  const otherId = req.user.role === 'patient' ? pair.clinicianId : pair.patientId;
  const [rows, other] = await Promise.all([
    all('SELECT * FROM messages WHERE patient_id = ? AND clinician_id = ? ORDER BY created_at ASC', pair.patientId, pair.clinicianId),
    get('SELECT name FROM users WHERE id = ?', otherId),
  ]);
  res.json({ with: { id: otherId, name: other.name, initials: initials(other.name) }, messages: rows.map((m) => messageDto(m, req.user.id)) });
});

const sendSchema = z.object({ text: z.string().trim().min(1, 'Write a message first').max(2000) });

r.post('/messages/threads/:patientId', async (req, res) => {
  const { text } = parse(sendSchema, req.body);
  const pair = await resolvePair(req.user, req.params.patientId);
  const id = newId();
  const createdAt = nowIso();
  await run(
    'INSERT INTO messages (id, patient_id, clinician_id, sender_id, text, created_at) VALUES (?,?,?,?,?,?)',
    id, pair.patientId, pair.clinicianId, req.user.id, text, createdAt,
  );
  const recipient = req.user.role === 'patient' ? pair.clinicianId : pair.patientId;
  await notify(recipient, 'message', `Message from ${req.user.name}`, text.length > 90 ? `${text.slice(0, 87)}...` : text);
  res.status(201).json({ message: { id, from: 'me', text, createdAt } });
});

export default r;
