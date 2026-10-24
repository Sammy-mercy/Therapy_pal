import { Router } from 'express';
import { z } from 'zod';
import { all, get, run, newId, nowIso } from '../lib/db.js';
import { HttpError, parse, clientNow, notFound } from '../lib/http.js';
import { requireAuth } from '../lib/auth.js';
import { initials } from '../lib/dto.js';
import { generateDoseNotifications, notify } from '../lib/notify.js';

const r = Router();
r.use(requireAuth);

/* ------------------------------------------------------------ notifications */

const notificationDto = (n) => ({ id: n.id, kind: n.kind, title: n.title, body: n.body, read: !!n.read, createdAt: n.created_at });

r.get('/notifications', (req, res) => {
  if (req.user.role === 'patient') generateDoseNotifications(req.user.id, clientNow(req.query));
  const rows = all('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 60', req.user.id);
  res.json({ notifications: rows.map(notificationDto), unread: rows.filter((n) => !n.read).length });
});

r.post('/notifications/read-all', (req, res) => {
  run('UPDATE notifications SET read = 1 WHERE user_id = ?', req.user.id);
  res.json({ ok: true });
});

r.post('/notifications/:id/read', (req, res) => {
  const out = run('UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?', req.params.id, req.user.id);
  if (!out.changes) throw notFound('Notification not found');
  res.json({ ok: true });
});

/* ----------------------------------------------------------------- messages */

/** Work out which patient/clinician pair a request refers to and check access. */
function resolvePair(user, patientId) {
  if (user.role === 'patient') {
    const p = get('SELECT clinician_id FROM patient_profiles WHERE user_id = ?', user.id);
    if (!p?.clinician_id) throw notFound('You are not linked to a clinician yet');
    return { patientId: user.id, clinicianId: p.clinician_id };
  }
  const p = get('SELECT user_id FROM patient_profiles WHERE user_id = ? AND clinician_id = ?', patientId, user.id);
  if (!p) throw notFound('Patient not found in your panel');
  return { patientId: p.user_id, clinicianId: user.id };
}

const messageDto = (m, viewerId) => ({ id: m.id, from: m.sender_id === viewerId ? 'me' : 'them', text: m.text, createdAt: m.created_at });

function threadSummary(patientId, clinicianId, viewer, displayName) {
  const last = get('SELECT * FROM messages WHERE patient_id = ? AND clinician_id = ? ORDER BY created_at DESC LIMIT 1', patientId, clinicianId);
  const unread = get(
    'SELECT COUNT(*) AS n FROM messages WHERE patient_id = ? AND clinician_id = ? AND sender_id != ? AND read = 0',
    patientId, clinicianId, viewer.id,
  );
  return {
    patientId, name: displayName, initials: initials(displayName), unread: unread.n,
    last: last ? messageDto(last, viewer.id) : null,
  };
}

r.get('/messages/threads', (req, res) => {
  let threads;
  if (req.user.role === 'patient') {
    const p = get('SELECT clinician_id FROM patient_profiles WHERE user_id = ?', req.user.id);
    const c = p?.clinician_id ? get('SELECT id, name FROM users WHERE id = ?', p.clinician_id) : null;
    threads = c ? [threadSummary(req.user.id, c.id, req.user, c.name)] : [];
  } else {
    const patients = all(
      'SELECT u.id, u.name FROM users u JOIN patient_profiles p ON p.user_id = u.id WHERE p.clinician_id = ?',
      req.user.id,
    );
    threads = patients.map((p) => threadSummary(p.id, req.user.id, req.user, p.name));
  }
  threads.sort((a, b) => (b.last?.createdAt || '').localeCompare(a.last?.createdAt || ''));
  res.json({ threads, unread: threads.reduce((n, t) => n + t.unread, 0) });
});

r.get('/messages/threads/:patientId', (req, res) => {
  const pair = resolvePair(req.user, req.params.patientId);
  run(
    'UPDATE messages SET read = 1 WHERE patient_id = ? AND clinician_id = ? AND sender_id != ?',
    pair.patientId, pair.clinicianId, req.user.id,
  );
  const rows = all('SELECT * FROM messages WHERE patient_id = ? AND clinician_id = ? ORDER BY created_at ASC', pair.patientId, pair.clinicianId);
  const otherId = req.user.role === 'patient' ? pair.clinicianId : pair.patientId;
  const other = get('SELECT name FROM users WHERE id = ?', otherId);
  res.json({ with: { id: otherId, name: other.name, initials: initials(other.name) }, messages: rows.map((m) => messageDto(m, req.user.id)) });
});

const sendSchema = z.object({ text: z.string().trim().min(1, 'Write a message first').max(2000) });

r.post('/messages/threads/:patientId', (req, res) => {
  const { text } = parse(sendSchema, req.body);
  const pair = resolvePair(req.user, req.params.patientId);
  const id = newId();
  const createdAt = nowIso();
  run(
    'INSERT INTO messages (id, patient_id, clinician_id, sender_id, text, created_at) VALUES (?,?,?,?,?,?)',
    id, pair.patientId, pair.clinicianId, req.user.id, text, createdAt,
  );
  const recipient = req.user.role === 'patient' ? pair.clinicianId : pair.patientId;
  notify(recipient, 'message', `Message from ${req.user.name}`, text.length > 90 ? `${text.slice(0, 87)}...` : text);
  res.status(201).json({ message: { id, from: 'me', text, createdAt } });
});

export default r;
