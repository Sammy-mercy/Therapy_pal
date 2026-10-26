import { get, all } from './db.js';

export const initials = (name = '') =>
  name.replace(/^Dr\.?\s+/i, '').split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join('');

const shapeRegimen = (r, prescriberName) => ({
  id: r.id,
  name: r.name,
  strength: r.strength,
  type: r.type,
  active: !!r.active,
  schedule: r.schedule,
  times: JSON.parse(r.times),
  started: r.started,
  prescriber: prescriberName || 'Self-added',
  note: r.note,
});

/** Shape several regimen rows at once (one lookup for all prescriber names). */
export async function regimenDtos(rows) {
  const ids = [...new Set(rows.map((r) => r.prescriber_id).filter(Boolean))];
  let names = new Map();
  if (ids.length) {
    const users = await all(`SELECT id, name FROM users WHERE id IN (${ids.map(() => '?').join(',')})`, ...ids);
    names = new Map(users.map((u) => [u.id, u.name]));
  }
  return rows.map((r) => shapeRegimen(r, names.get(r.prescriber_id)));
}

export async function regimenDto(row) {
  return (await regimenDtos([row]))[0];
}

/** Full profile for /api/me, shaped per role. */
export async function profileDto(userId) {
  const u = await get('SELECT * FROM users WHERE id = ?', userId);
  const base = {
    id: u.id, role: u.role, name: u.name, initials: initials(u.name), email: u.email,
    phone: u.phone, dob: u.dob, memberSince: u.created_at, prefs: JSON.parse(u.prefs),
  };
  if (u.role === 'clinician') {
    const [c, clinics] = await Promise.all([
      get('SELECT * FROM clinician_profiles WHERE user_id = ?', u.id),
      all('SELECT id, name, role, address, patients FROM clinics WHERE clinician_id = ?', u.id),
    ]);
    return { ...base, npi: c?.npi || '', specialization: c?.specialization || '', license: c?.license || '', clinics };
  }
  const p = await get('SELECT * FROM patient_profiles WHERE user_id = ?', u.id);
  const clinician = p?.clinician_id ? await get('SELECT id, name FROM users WHERE id = ?', p.clinician_id) : null;
  return { ...base, plan: p?.plan || '', clinician: clinician ? { id: clinician.id, name: clinician.name } : null };
}
