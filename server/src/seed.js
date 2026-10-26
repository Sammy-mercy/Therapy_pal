import bcrypt from 'bcryptjs';
import { pathToFileURL } from 'node:url';
import { db, get, ready, batch, stmt, newId, isRemoteDb } from './lib/db.js';
import { addDays, eachDay } from './lib/adherence.js';

const PASSWORD = 'therapy-pal';

function rng(seed) {
  let a = [...seed].reduce((h, c) => (Math.imul(h ^ c.charCodeAt(0), 16777619) >>> 0), 2166136261);
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const pad = (n) => String(n).padStart(2, '0');
const localDay = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const hhmm = (min) => `${pad(Math.floor(min / 60) % 24)}:${pad(min % 60)}`;
const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
const minutesAgo = (m) => new Date(Date.now() - m * 60000).toISOString();

/** Loads the demo clinician, patients, doses, messages and history. Expects an empty database. */
export async function seedDemo() {
  const hash = bcrypt.hashSync(PASSWORD, 10);
  const now = new Date();
  const today = localDay(now);
  const nowMin = now.getHours() * 60 + now.getMinutes();

  // Collect every statement first, then send them in a few large groups (far fewer network round trips).
  const S = [];
  const add = (sql, ...args) => S.push(stmt(sql, ...args));

  const user = (role, name, email, phone = '', dob = '', daysAgo = 30) => {
    const id = newId();
    add(
      'INSERT INTO users (id, role, email, password_hash, name, phone, dob, created_at) VALUES (?,?,?,?,?,?,?,?)',
      id, role, email, hash, name, phone, dob, minutesAgo(daysAgo * 1440),
    );
    return id;
  };

  /* ---- clinician ---- */
  const doc = user('clinician', 'Dr. Sarah Carter', 's.carter@downtownclinic.org', '(415) 555-0100', '', 400);
  add('INSERT INTO clinician_profiles (user_id, npi, specialization, license) VALUES (?,?,?,?)', doc, '1740293847', 'Internal Medicine', 'CA-9928471');
  add('INSERT INTO clinics (id, clinician_id, name, role, address, patients) VALUES (?,?,?,?,?,?)', newId(), doc, 'Downtown Clinic', 'Attending physician', '420 Market St, Suite 300', 4);
  add('INSERT INTO clinics (id, clinician_id, name, role, address, patients) VALUES (?,?,?,?,?,?)', newId(), doc, 'Westside Clinic', 'Consulting physician', '1180 West Ave, Floor 2', 2);

  /* ---- patients: [name, email, phone, dob, note, target adherence %, regimen items] ---- */
  const panel = [
    ['Alex Rivera', 'alex.rivera@email.com', '(415) 555-0134', 'March 14, 1991', 'Post-operative ankle recovery', 92, [
      ['Ibuprofen', '200 mg', 'medication', '3 times daily, after meals', ['08:00', '13:00', '20:00'], 18, 'Take with food to avoid stomach upset.', true],
      ['Ankle Exercises', '15 min set', 'therapy', '2 times daily, morning and evening', ['09:00', '19:00'], 12, 'Dorsiflexion, ankle circles, then resistance-band sets.', true],
      ['Amoxicillin', '500 mg', 'medication', '2 times daily', ['08:00', '20:00'], 9, 'Complete the full 10-day course.', true],
      ['Vitamin D3', '1000 IU', 'medication', 'Once daily', ['08:00'], 25, 'Paused - vitamin D level is back within range.', false],
    ]],
    ['Maya Chen', 'maya.chen@email.com', '(415) 555-0171', 'June 2, 1968', 'Hypertension management', 88, [
      ['Lisinopril', '10 mg', 'medication', 'Once daily, morning', ['08:00'], 40, 'Take at the same time each morning.', true]]],
    ['Jordan Blake', 'jordan.blake@email.com', '(415) 555-0188', 'January 19, 1999', 'Shoulder rehabilitation', 55, [
      ['Physical therapy', '30 min session', 'therapy', '2 times daily', ['09:00', '18:00'], 40, 'Band work and mobility sets.', true]]],
    ['Priya Nair', 'priya.nair@email.com', '(415) 555-0142', 'October 8, 1980', 'Type 2 diabetes', 76, [
      ['Metformin', '500 mg', 'medication', '2 times daily, with meals', ['08:00', '20:00'], 40, 'Take with food.', true]]],
    ['Sam Okafor', 'sam.okafor@email.com', '(415) 555-0119', 'April 22, 1995', 'Persistent asthma', 81, [
      ['Budesonide inhaler', '200 mcg', 'medication', '2 times daily', ['07:00', '19:00'], 40, 'Rinse mouth after each use.', true]]],
    ['Lena Fischer', 'lena.fischer@email.com', '(415) 555-0163', 'August 30, 1963', 'Knee replacement recovery', 64, [
      ['Post-op physiotherapy', '20 min', 'therapy', '2 times daily', ['10:00', '19:30'], 30, 'Range-of-motion and strengthening routine.', true]]],
  ];

  const ids = {};
  for (const [name, email, phone, dob, note, target, items] of panel) {
    const pid = user('patient', name, email, phone, dob, 60);
    ids[name] = pid;
    add('INSERT INTO patient_profiles (user_id, clinician_id, plan, note) VALUES (?,?,?,?)', pid, doc, 'Recovery plan', note);
    const rand = rng(name);
    for (const [rname, strength, type, schedule, times, daysBack, rnote, active] of items) {
      const rid = newId();
      const started = addDays(today, -daysBack);
      add(
        `INSERT INTO regimens (id, patient_id, prescriber_id, name, strength, type, active, schedule, times, started, start_time, note)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
        rid, pid, doc, rname, strength, type, active ? 1 : 0, schedule, JSON.stringify(times), started, '00:00', rnote,
      );
      if (!active) continue;
      for (const day of eachDay(started, today)) {
        for (const slot of times) {
          if (day === today && toMin(slot) > nowMin - 60) continue; // leave recent/future doses open
          if (rand() * 100 >= target) continue; // missed
          add(
            'INSERT INTO dose_logs (id, patient_id, regimen_id, day, slot, logged_time, created_at) VALUES (?,?,?,?,?,?,?)',
            newId(), pid, rid, day, slot, hhmm(toMin(slot) + Math.floor(rand() * 25)), minutesAgo(1),
          );
        }
      }
    }
  }

  /* ---- messages (patient -> clinician threads) ---- */
  const msg = (patient, fromDoctor, text, agoMin, read) => add(
    'INSERT INTO messages (id, patient_id, clinician_id, sender_id, text, read, created_at) VALUES (?,?,?,?,?,?,?)',
    newId(), ids[patient], doc, fromDoctor ? doc : ids[patient], text, read ? 1 : 0, minutesAgo(agoMin),
  );
  msg('Alex Rivera', false, 'Hi Dr. Carter - is it okay if I take the ibuprofen a bit late on workdays?', 200, true);
  msg('Alex Rivera', true, 'Hi Alex - yes, keep it within about an hour of the scheduled time and always with food.', 192, true);
  msg('Alex Rivera', false, 'Got it, thanks. The ankle exercises are getting easier.', 167, false);
  msg('Jordan Blake', false, 'I missed two sessions this week, the band work is really sore.', 1600, false);
  msg('Jordan Blake', false, 'Should I keep going or rest a few days?', 1598, false);
  msg('Maya Chen', true, 'Your readings look steady this month. Keep the morning dose where it is.', 4300, true);
  msg('Maya Chen', false, 'Thank you, that is a relief.', 4270, true);
  msg('Lena Fischer', false, 'The physio schedule is a lot on top of work - can we move the evening block?', 5800, true);
  msg('Lena Fischer', true, 'Yes. Shift it to 7:30 PM and log it the same day for the record.', 5780, true);

  /* ---- notifications for Alex ---- */
  const note = (kind, title, body, agoMin, read) => add(
    'INSERT INTO notifications (id, user_id, kind, title, body, read, created_at) VALUES (?,?,?,?,?,?,?)',
    newId(), ids['Alex Rivera'], kind, title, body, read ? 1 : 0, minutesAgo(agoMin),
  );
  note('regimen', 'New regimen assigned by Dr. Carter', 'Ankle Exercises added to your plan.', 170, false);
  note('message', 'Message from Dr. Sarah Carter', 'Hi Alex - yes, keep it within about an hour of the scheduled time and always with food.', 192, false);

  /* ---- medical history for Alex ---- */
  const rec = (date, title, detail, place) => add(
    'INSERT INTO history (id, patient_id, date, title, detail, place) VALUES (?,?,?,?,?,?)', newId(), ids['Alex Rivera'], date, title, detail, place);
  rec('2026-09-24', 'Ankle arthroscopy - follow-up', 'Range of motion improving; cleared for progressive loading.', 'Downtown Clinic');
  rec('2026-09-18', 'Physical therapy intake', 'Twice-daily exercises prescribed, 15 minutes per set.', 'Downtown Clinic');
  rec('2026-09-12', 'Ankle arthroscopy', 'Outpatient procedure, no complications.', 'Westside Surgical Center');
  rec('2026-09-08', 'Routine blood panel', 'Vitamin D low, all other markers within range.', 'Downtown Clinic');
  rec('2026-08-21', 'Allergy consult', 'Penicillin tolerance confirmed after oral challenge.', 'Downtown Clinic');

  for (let i = 0; i < S.length; i += 150) await batch(S.slice(i, i + 150));
}

// `node src/seed.js` seeds an empty database; add --reset to wipe everything first.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  await ready();
  if (args.includes('--reset')) {
    if (isRemoteDb && !args.includes('--confirm-remote')) {
      console.error('[seed] Refusing to wipe a hosted database. This would delete ALL real data.');
      console.error('[seed] If you really mean it, add --confirm-remote.');
      process.exit(1);
    }
    const tables = ['history', 'messages', 'notifications', 'dose_logs', 'regimens', 'clinics', 'patient_profiles', 'clinician_profiles', 'users'];
    await db.batch(tables.map((t) => `DELETE FROM ${t}`), 'write');
    console.log('[seed] Existing data cleared.');
  }
  if (await get('SELECT id FROM users LIMIT 1')) {
    console.log('[seed] Database already has users - run "npm run reset" to start over.');
  } else {
    await seedDemo();
    console.log(`[seed] Demo data loaded. Password for every demo account: ${PASSWORD}`);
  }
}
