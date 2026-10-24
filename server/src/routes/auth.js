import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { get, run, newId, nowIso, tx } from '../lib/db.js';
import { HttpError, parse } from '../lib/http.js';
import { requireAuth, signToken } from '../lib/auth.js';
import { profileDto } from '../lib/dto.js';

const r = Router();

const email = z.string().trim().toLowerCase().pipe(z.email('Enter a valid email address'));
const password = z.string().min(8, 'Password must be at least 8 characters').max(128);

const registerSchema = z.discriminatedUnion('role', [
  z.object({
    role: z.literal('patient'),
    name: z.string().trim().min(2, 'Enter your full name').max(100),
    email, password,
    phone: z.string().trim().max(40).optional().default(''),
    dob: z.string().trim().max(40).optional().default(''),
    clinicianEmail: email.optional(),
  }),
  z.object({
    role: z.literal('clinician'),
    name: z.string().trim().min(2, 'Enter your full name').max(100),
    email, password,
    npi: z.string().trim().regex(/^\d{10}$/, 'NPI must be 10 digits'),
    specialization: z.string().trim().min(2).max(100),
    license: z.string().trim().max(60).optional().default(''),
  }),
]);

r.post('/register', (req, res) => {
  const d = parse(registerSchema, req.body);
  if (get('SELECT id FROM users WHERE email = ?', d.email)) throw new HttpError(409, 'An account with this email already exists');

  const id = newId();
  const hash = bcrypt.hashSync(d.password, 12);
  tx(() => {
    run(
      'INSERT INTO users (id, role, email, password_hash, name, phone, dob, created_at) VALUES (?,?,?,?,?,?,?,?)',
      id, d.role, d.email, hash, d.name, d.phone ?? '', d.dob ?? '', nowIso(),
    );
    if (d.role === 'clinician') {
      run('INSERT INTO clinician_profiles (user_id, npi, specialization, license) VALUES (?,?,?,?)', id, d.npi, d.specialization, d.license);
    } else {
      const clinician = d.clinicianEmail
        ? get("SELECT id FROM users WHERE email = ? AND role = 'clinician'", d.clinicianEmail)
        : null;
      if (d.clinicianEmail && !clinician) throw new HttpError(404, 'No clinician found with that email');
      run('INSERT INTO patient_profiles (user_id, clinician_id, plan) VALUES (?,?,?)', id, clinician?.id ?? null, 'Care plan');
    }
  });
  res.status(201).json({ token: signToken({ id, role: d.role }), user: profileDto(id) });
});

const loginSchema = z.object({
  email,
  password: z.string().min(1, 'Enter your password'),
  role: z.enum(['patient', 'clinician']).optional(),
});

r.post('/login', (req, res) => {
  const d = parse(loginSchema, req.body);
  const user = get('SELECT * FROM users WHERE email = ?', d.email);
  // Same message for unknown email and wrong password.
  if (!user || !bcrypt.compareSync(d.password, user.password_hash)) throw new HttpError(401, 'Incorrect email or password');
  if (d.role && d.role !== user.role) throw new HttpError(403, `This account is a ${user.role} account. Choose "${user.role}" to sign in.`);
  res.json({ token: signToken(user), user: profileDto(user.id) });
});

r.get('/me', requireAuth, (req, res) => res.json({ user: profileDto(req.user.id) }));

const updateSchema = z.object({
  name: z.string().trim().min(2, 'Enter your full name').max(100).optional(),
  email: email.optional(),
  phone: z.string().trim().max(40).optional(),
});

r.patch('/me', requireAuth, (req, res) => {
  const d = parse(updateSchema, req.body);
  if (d.email && get('SELECT id FROM users WHERE email = ? AND id != ?', d.email, req.user.id)) {
    throw new HttpError(409, 'That email is already in use');
  }
  const cur = get('SELECT name, email, phone FROM users WHERE id = ?', req.user.id);
  run('UPDATE users SET name = ?, email = ?, phone = ? WHERE id = ?', d.name ?? cur.name, d.email ?? cur.email, d.phone ?? cur.phone, req.user.id);
  res.json({ user: profileDto(req.user.id) });
});

const prefsSchema = z.object({
  doseReminders: z.boolean().optional(),
  missedDose: z.boolean().optional(),
  clinicianMessages: z.boolean().optional(),
  weeklySummary: z.boolean().optional(),
});

r.patch('/me/prefs', requireAuth, (req, res) => {
  const d = parse(prefsSchema, req.body);
  const cur = JSON.parse(get('SELECT prefs FROM users WHERE id = ?', req.user.id).prefs);
  run('UPDATE users SET prefs = ? WHERE id = ?', JSON.stringify({ ...cur, ...d }), req.user.id);
  res.json({ user: profileDto(req.user.id) });
});

export default r;
