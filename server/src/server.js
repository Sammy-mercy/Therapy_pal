import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { get, ready } from './lib/db.js';
import { errorHandler, HttpError } from './lib/http.js';
import authRoutes from './routes/auth.js';
import patientRoutes from './routes/patient.js';
import clinicianRoutes from './routes/clinician.js';
import sharedRoutes from './routes/shared.js';
import { seedDemo } from './seed.js';

const app = express();
app.disable('x-powered-by');
// Behind Vercel's (or any host's) proxy the real visitor address arrives in a header.
// Without this, the login rate limit would treat every visitor as one person.
app.set('trust proxy', 1);
app.use(helmet());

const origins = (process.env.CORS_ORIGIN || '*').split(',').map((s) => s.trim()).filter(Boolean);
if (process.env.NODE_ENV === 'production' && origins.includes('*')) {
  console.warn('[cors] CORS_ORIGIN is "*" in production. Set it to your app address, e.g. https://your-app.vercel.app');
}
app.use(cors({ origin: origins.includes('*') ? true : origins }));
app.use(express.json({ limit: '100kb' }));

app.get('/api/health', (_req, res) => res.json({ ok: true, service: 'therapy-pal', time: new Date().toISOString() }));

// Make sure the database tables exist before any real request (runs once per server instance).
app.use('/api', async (_req, _res, next) => {
  await ready();
  next();
});

// Slow down password guessing on login/registration.
app.use('/api/auth/login', rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false }));
app.use('/api/auth/register', rateLimit({ windowMs: 60 * 60 * 1000, limit: 20, standardHeaders: 'draft-8', legacyHeaders: false }));

app.use('/api/auth', authRoutes);
app.use('/api/patient', patientRoutes);
app.use('/api/clinician', clinicianRoutes);
app.use('/api', sharedRoutes);

app.use((_req, _res, next) => next(new HttpError(404, 'Route not found')));
app.use(errorHandler);

// On Vercel the platform runs `app` itself. Locally we start our own listener.
if (!process.env.VERCEL) {
  if (process.env.SEED_DEMO_DATA === 'true') {
    await ready();
    if (!(await get('SELECT id FROM users LIMIT 1'))) {
      await seedDemo();
      console.log('[seed] Demo data loaded. Sign in with s.carter@downtownclinic.org or alex.rivera@email.com (password: therapy-pal)');
    }
  }
  const port = Number(process.env.PORT) || 4000;
  app.listen(port, () => console.log(`Therapy Pal API listening on http://localhost:${port}`));
}

export default app;
