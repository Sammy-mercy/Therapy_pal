import jwt from 'jsonwebtoken';
import { get } from './db.js';
import { HttpError } from './http.js';

const isProd = process.env.NODE_ENV === 'production';
let secret = process.env.JWT_SECRET;

if (!secret) {
  if (isProd) {
    console.error('JWT_SECRET is not set. Add it to server/.env.local before running in production.');
    process.exit(1);
  }
  // Development only: a random per-process secret. Tokens stop working on restart.
  secret = `dev-${Math.random().toString(36).slice(2)}${Date.now()}`;
  console.warn('[auth] JWT_SECRET is empty - using a temporary dev secret. Set it in .env.local.');
}

const expiresIn = process.env.JWT_EXPIRES_IN || '7d';

export const signToken = (user) => jwt.sign({ sub: user.id, role: user.role }, secret, { expiresIn });

export async function requireAuth(req, _res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new HttpError(401, 'Sign in to continue');
  let payload;
  try {
    payload = jwt.verify(token, secret);
  } catch {
    throw new HttpError(401, 'Your session has expired. Please sign in again.');
  }
  const user = await get('SELECT id, role, email, name FROM users WHERE id = ?', payload.sub);
  if (!user) throw new HttpError(401, 'Account no longer exists');
  req.user = user;
  next();
}

export const requireRole = (role) => (req, _res, next) => {
  if (req.user?.role !== role) throw new HttpError(403, `This area is for ${role}s only`);
  next();
};
