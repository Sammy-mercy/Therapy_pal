import { z } from 'zod';

export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

/** Parse `data` with a zod schema or throw a 400 HttpError. */
export function parse(schema, data) {
  const result = schema.safeParse(data ?? {});
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join('.'),
      message: i.message,
    }));
    throw new HttpError(400, details[0]?.message || 'Invalid request', details);
  }
  return result.data;
}

export const dayStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
export const timeStr = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:MM (24h)');

/** Client-local "now" (day + time) so results match the user's timezone. */
export function clientNow(query = {}) {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const fallbackDay = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const fallbackTime = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  const day = dayStr.safeParse(query.day).success ? query.day : fallbackDay;
  const time = timeStr.safeParse(query.time).success ? query.time : fallbackTime;
  return { day, time };
}

export function notFound(msg = 'Not found') {
  return new HttpError(404, msg);
}

export function errorHandler(err, _req, res, _next) {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({
    error: {
      message: status >= 500 ? 'Something went wrong' : err.message,
      ...(err.details ? { details: err.details } : {}),
    },
  });
}
