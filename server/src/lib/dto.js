import { get, all } from './db.js';

export const initials = (name = '') =>
  name.replace(/^Dr\.?\s+/i, '').split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join('');

export function regimenDto(r) {
  const prescriber = r.prescriber_id ? get('SELECT name FROM users WHERE id = ?', r.prescriber_id) : null;
  return {
    id: r.id,
    name: r.name,
    strength: r.strength,
    type: r.type,
    active: !!r.active,
    schedule: r.schedule,
    times: JSON.parse(r.times),
    started: r.started,
    prescriber: prescriber?.name || 'Self-added',
    note: r.note,
  };
}

/** Full profile for /api/me, shaped per role. */
export function profileDto(userId) {
  const u = get('SELECT * FROM users WHERE id = ?', userId);
  const base = {
    id: u.id, role: u.role, name: u.name, initials: initials(u.name), email: u.email,
    phone: u.phone, dob: u.dob, memberSince: u.created_at, prefs: JSON.parse(u.prefs),
  };
  if (u.role === 'clinician') {
    const c = get('SELECT * FROM clinician_profiles WHERE user_id = ?', u.id) || {};
    const clinics = all('SELECT id, name, role, address, patients FROM clinics WHERE clinician_id = ?', u.id);
    return { ...base, npi: c.npi || '', specialization: c.specialization || '', license: c.license || '', clinics };
  }
  const p = get('SELECT * FROM patient_profiles WHERE user_id = ?', u.id) || {};
  const clinician = p.clinician_id ? get('SELECT id, name FROM users WHERE id = ?', p.clinician_id) : null;
  return { ...base, plan: p.plan || '', clinician: clinician ? { id: clinician.id, name: clinician.name } : null };
}
