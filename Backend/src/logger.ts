import fs from 'fs';
import path from 'path';
import { Request, Response, NextFunction } from 'express';

// Lightweight, dependency-free logger. Every line goes to stdout/stderr (so it
// shows up in `pm2 logs` / the Hostinger Node console) and, when LOG_TO_FILE is
// on, is appended to logs/YYYY-MM-DD.log so history survives a restart.
//
// Env knobs:
//   LOG_LEVEL   debug | info | warn | error        (default: debug in dev, info otherwise)
//   LOG_TO_FILE true | false                       (default: true)
//   LOG_DIR     directory for log files            (default: <Backend>/logs)
//   LOG_BODIES  true | false — log request bodies  (default: false; bodies can hold device ids)
//   LOG_RETENTION_DAYS  how many daily files to keep (default: 14)

type Level = 'debug' | 'info' | 'warn' | 'error';

const LEVEL_ORDER: Record<Level, number> = { debug: 0, info: 1, warn: 2, error: 3 };

const envLevel = (process.env.LOG_LEVEL || '').toLowerCase() as Level;
const MIN_LEVEL: Level = LEVEL_ORDER[envLevel] !== undefined
  ? envLevel
  : (process.env.NODE_ENV === 'production' ? 'info' : 'debug');

const LOG_TO_FILE = (process.env.LOG_TO_FILE || 'true').toLowerCase() !== 'false';
const LOG_BODIES = (process.env.LOG_BODIES || 'false').toLowerCase() === 'true';
const LOG_DIR = process.env.LOG_DIR || path.join(__dirname, '..', 'logs');
const RETENTION_DAYS = parseInt(process.env.LOG_RETENTION_DAYS || '14', 10);

// The whole app reasons in IST (session expiry, daily balances), so timestamps
// are IST too — otherwise a log line and a balance row look 5.5h apart.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function istParts(now: Date = new Date()) {
  const ist = new Date(now.getTime() + IST_OFFSET_MS);
  const p = (n: number, w = 2) => String(n).padStart(w, '0');
  return {
    date: `${ist.getUTCFullYear()}-${p(ist.getUTCMonth() + 1)}-${p(ist.getUTCDate())}`,
    time: `${p(ist.getUTCHours())}:${p(ist.getUTCMinutes())}:${p(ist.getUTCSeconds())}.${p(ist.getUTCMilliseconds(), 3)}`,
  };
}

let fileStream: fs.WriteStream | null = null;
let fileStreamDate = '';

function getFileStream(dateStr: string): fs.WriteStream | null {
  if (!LOG_TO_FILE) return null;
  if (fileStream && fileStreamDate === dateStr) return fileStream;
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fileStream?.end();
    fileStream = fs.createWriteStream(path.join(LOG_DIR, `${dateStr}.log`), { flags: 'a' });
    // A failed file write must never take the API down with it.
    fileStream.on('error', (e) => {
      // eslint-disable-next-line no-console
      console.error('[LOGGER] File stream error, continuing console-only:', e.message);
      fileStream = null;
    });
    fileStreamDate = dateStr;
    pruneOldLogs();
    return fileStream;
  } catch (e: any) {
    // eslint-disable-next-line no-console
    console.error('[LOGGER] Cannot open log file, continuing console-only:', e.message);
    return null;
  }
}

function pruneOldLogs() {
  if (!Number.isFinite(RETENTION_DAYS) || RETENTION_DAYS <= 0) return;
  try {
    const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    for (const name of fs.readdirSync(LOG_DIR)) {
      if (!/^\d{4}-\d{2}-\d{2}\.log$/.test(name)) continue;
      const full = path.join(LOG_DIR, name);
      if (fs.statSync(full).mtimeMs < cutoff) fs.unlinkSync(full);
    }
  } catch {
    // Pruning is best-effort — never worth failing a log write over.
  }
}

// Objects going into a log line: keep them short and single-line.
function fmtMeta(meta?: unknown): string {
  if (meta === undefined || meta === null) return '';
  if (typeof meta === 'string') return ' ' + meta;
  try {
    const s = JSON.stringify(meta, (_k, v) => (v instanceof Error ? { message: v.message, stack: v.stack } : v));
    return s && s !== '{}' ? ' ' + (s.length > 2000 ? s.slice(0, 2000) + '…[truncated]' : s) : '';
  } catch {
    return ' [unserializable meta]';
  }
}

function write(level: Level, scope: string, message: string, meta?: unknown) {
  if (LEVEL_ORDER[level] < LEVEL_ORDER[MIN_LEVEL]) return;
  const { date, time } = istParts();
  const line = `${date} ${time} IST ${level.toUpperCase().padEnd(5)} [${scope}] ${message}${fmtMeta(meta)}`;
  // eslint-disable-next-line no-console
  (level === 'error' ? console.error : level === 'warn' ? console.warn : console.log)(line);
  getFileStream(date)?.write(line + '\n');
}

export const log = {
  debug: (scope: string, message: string, meta?: unknown) => write('debug', scope, message, meta),
  info: (scope: string, message: string, meta?: unknown) => write('info', scope, message, meta),
  warn: (scope: string, message: string, meta?: unknown) => write('warn', scope, message, meta),
  error: (scope: string, message: string, err?: unknown, meta?: unknown) => {
    const e = err as any;
    write('error', scope, message, {
      ...(typeof meta === 'object' && meta ? meta : meta !== undefined ? { meta } : {}),
      error: e?.message ?? String(err ?? ''),
      name: e?.name,
      code: e?.code,
      stack: e?.stack,
    });
  },
};

// Every request gets a short id that appears on its start line, its finish line,
// and any error logged while handling it — that's how you tie them together.
let reqCounter = 0;
function nextRequestId(): string {
  reqCounter = (reqCounter + 1) % 1_000_000;
  return reqCounter.toString(36).padStart(4, '0');
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      requestId?: string;
      startedAt?: number;
    }
  }
}

const SENSITIVE_BODY_KEYS = new Set(['password', 'token', 'secret', 'authorization']);

// Health/time are polled constantly and the SSE stream is long-lived — a normal
// info line for each would bury everything else. They drop to debug unless they
// actually fail.
const QUIET_PATHS = new Set(['/api/health', '/api/time', '/api/events']);

function safeBody(body: any): unknown {
  if (!LOG_BODIES || !body || typeof body !== 'object') return undefined;
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(body)) {
    out[k] = SENSITIVE_BODY_KEYS.has(k.toLowerCase()) ? '[redacted]' : v;
  }
  return Object.keys(out).length ? out : undefined;
}

// Logs one line when a request arrives and one when the response is sent,
// with status and duration. 4xx logs at warn, 5xx at error, everything else info.
export function requestLogger(req: Request, res: Response, next: NextFunction) {
  req.requestId = nextRequestId();
  req.startedAt = Date.now();

  const caller = req.headers['x-staff-id']
    ? `staff:${req.headers['x-staff-id']}`
    : req.headers['x-android-id']
      ? `device:${String(req.headers['x-android-id']).slice(0, 8)}…`
      : 'anon';

  log.debug('HTTP', `→ ${req.method} ${req.originalUrl}`, {
    id: req.requestId,
    caller,
    ip: req.ip,
    body: safeBody(req.body),
  });

  res.on('finish', () => {
    const ms = Date.now() - (req.startedAt ?? Date.now());
    const level: Level = res.statusCode >= 500
      ? 'error'
      : res.statusCode >= 400
        ? 'warn'
        : QUIET_PATHS.has(req.path) ? 'debug' : 'info';
    write(level, 'HTTP', `← ${req.method} ${req.originalUrl} ${res.statusCode} ${ms}ms`, {
      id: req.requestId,
      caller,
    });
    // Anything sluggish is worth seeing even when it succeeds.
    if (ms > 1000) log.warn('HTTP', `SLOW ${req.method} ${req.originalUrl} took ${ms}ms`, { id: req.requestId });
  });

  next();
}

// Wraps an async route so a thrown/rejected error is logged with its stack and
// turned into a JSON 500 instead of vanishing into an unhandled rejection.
export function wrap(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<any> | any,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

// Terminal Express error handler — must be registered after all routes.
export function errorHandler(err: any, req: Request, res: Response, _next: NextFunction) {
  log.error('UNHANDLED', `${req.method} ${req.originalUrl} failed`, err, { id: req.requestId });
  if (res.headersSent) return;
  res.status(err?.status || 500).json({ error: err?.message || 'Internal server error' });
}

export function notFoundHandler(req: Request, res: Response) {
  log.warn('HTTP', `404 no route for ${req.method} ${req.originalUrl}`, { id: req.requestId });
  res.status(404).json({ error: `No route for ${req.method} ${req.originalUrl}` });
}

// Last line of defence: a crash or a stray rejection should leave a trace.
export function installProcessLogging() {
  process.on('unhandledRejection', (reason) => {
    log.error('PROCESS', 'Unhandled promise rejection', reason);
  });
  process.on('uncaughtException', (err) => {
    log.error('PROCESS', 'Uncaught exception — process will exit', err);
    // Let the file stream flush before the process manager restarts us.
    setTimeout(() => process.exit(1), 250);
  });
  for (const sig of ['SIGINT', 'SIGTERM'] as const) {
    process.on(sig, () => {
      log.info('PROCESS', `Received ${sig}, shutting down.`);
      fileStream?.end();
      process.exit(0);
    });
  }
}

export const loggerConfig = { MIN_LEVEL, LOG_TO_FILE, LOG_DIR, LOG_BODIES, RETENTION_DAYS };
