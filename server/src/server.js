import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { get } from './lib/db.js';
import { errorHandler, HttpError } from './lib/http.js';
import authRoutes from './routes/auth.js';
import patientRoutes from './routes/patient.js';
import clinicianRoutes from './routes/clinician.js';
import sharedRoutes from './routes/shared.js';
import { seedDemo } from './seed.js';

const app = express();
app.disable('x-powered-by');
app.use(helmet());

const origins = (process.env.CORS_ORIGIN || '*').split(',').map((s) => s.trim());
app.use(cors({ origin: origins.includes('*') ? true : origins }));
app.use(express.json({ limit: '100kb' }));

app.get('/api/health', (_req, res) => res.json({ ok: true, service: 'therapy-pal', time: new Date().toISOString() }));

// Slow down password guessing on login/registration.
app.use('/api/auth/login', rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false }));
app.use('/api/auth/register', rateLimit({ windowMs: 60 * 60 * 1000, limit: 20, standardHeaders: 'draft-8', legacyHeaders: false }));

app.use('/api/auth', authRoutes);
app.use('/api/patient', patientRoutes);
app.use('/api/clinician', clinicianRoutes);
app.use('/api', sharedRoutes);

app.use((_req, _res, next) => next(new HttpError(404, 'Route not found')));
app.use(errorHandler);

if (process.env.SEED_DEMO_DATA === 'true' && !get('SELECT id FROM users LIMIT 1')) {
  seedDemo();
  console.log('[seed] Demo data loaded. Sign in with s.carter@downtownclinic.org or alex.rivera@email.com (password: therapy-pal)');
}

const port = Number(process.env.PORT) || 4000;
app.listen(port, () => console.log(`Therapy Pal API listening on http://localhost:${port}`));
