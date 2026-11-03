import { createHmac, randomBytes, timingSafeEqual } from 'crypto';
import { promises as fs } from 'fs';
import { HttpError } from './errors';
import { dataPath } from './store';
import { getUser, type Role, type User } from './users';

/** Identité attachée à une requête : un utilisateur, ou le jeton de service API_TOKEN. */
export interface Principal {
  id: string;
  name: string;
  email: string;
  role: Role;
  service: boolean;
}

const TOKEN_PREFIX = 'ms1';
const TOKEN_TTL_MS = 14 * 24 * 60 * 60 * 1000;

const holder = globalThis as unknown as { __maillerAuthSecret?: Promise<Buffer> };

/** Clé de signature : AUTH_SECRET, sinon data/auth-secret (générée au premier lancement). */
function secret(): Promise<Buffer> {
  holder.__maillerAuthSecret ??= (async () => {
    const fromEnv = (process.env.AUTH_SECRET ?? '').trim();
    if (fromEnv) return Buffer.from(fromEnv, 'utf8');
    const file = dataPath('auth-secret');
    try {
      return Buffer.from((await fs.readFile(file, 'utf8')).trim(), 'hex');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
    const generated = randomBytes(48).toString('hex');
    await fs.mkdir(dataPath(), { recursive: true });
    try {
      await fs.writeFile(file, generated, { encoding: 'utf8', flag: 'wx', mode: 0o600 });
      return Buffer.from(generated, 'hex');
    } catch {
      // Créée entre-temps par une requête concurrente
      return Buffer.from((await fs.readFile(file, 'utf8')).trim(), 'hex');
    }
  })();
  return holder.__maillerAuthSecret;
}

const b64 = (value: Buffer | string) => Buffer.from(value).toString('base64url');

async function sign(payload: string): Promise<Buffer> {
  return createHmac('sha256', await secret()).update(`${TOKEN_PREFIX}.${payload}`).digest();
}

interface TokenPayload {
  sub: string;
  ver: number;
  exp: number;
}

export async function issueToken(user: User): Promise<{ token: string; expiresAt: string }> {
  const exp = Date.now() + TOKEN_TTL_MS;
  const payload = b64(JSON.stringify({ sub: user.id, ver: user.tokenVersion, exp } satisfies TokenPayload));
  const signature = b64(await sign(payload));
  return { token: `${TOKEN_PREFIX}.${payload}.${signature}`, expiresAt: new Date(exp).toISOString() };
}

function sameBytes(a: Buffer, b: Buffer): boolean {
  return a.length === b.length && timingSafeEqual(a, b);
}

/** Jeton de service (.env.local) : accès administrateur pour les scripts. */
function serviceToken(): string {
  return (process.env.API_TOKEN ?? '').trim();
}

export function isSetupKeyRequired(): boolean {
  return serviceToken() !== '';
}

export function isSetupKeyValid(key: string | undefined): boolean {
  const expected = serviceToken();
  return expected === '' || sameBytes(Buffer.from(key ?? ''), Buffer.from(expected));
}

export async function principalFromToken(token: string): Promise<Principal | null> {
  const service = serviceToken();
  if (service !== '' && sameBytes(Buffer.from(token), Buffer.from(service))) {
    return { id: 'service', name: 'Jeton de service', email: '', role: 'admin', service: true };
  }

  const [prefix, payload, signature] = token.split('.');
  if (prefix !== TOKEN_PREFIX || !payload || !signature) return null;
  if (!sameBytes(Buffer.from(signature, 'base64url'), await sign(payload))) return null;

  let data: TokenPayload;
  try {
    data = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as TokenPayload;
  } catch {
    return null;
  }
  if (typeof data.exp !== 'number' || data.exp < Date.now()) return null;

  const user = await getUser(data.sub);
  if (!user || !user.active || user.tokenVersion !== data.ver) return null;
  return { id: user.id, name: user.name, email: user.email, role: user.role, service: false };
}

// ── Limitation des tentatives de connexion (en mémoire, par adresse IP + e-mail)

const MAX_FAILURES = 5;
const WINDOW_MS = 10 * 60 * 1000;
const attempts = new Map<string, { count: number; first: number }>();

export function clientKey(req: Request, email: string): string {
  const ip = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() || 'local';
  return `${ip}|${email.trim().toLowerCase()}`;
}

export function assertLoginAllowed(key: string): void {
  const entry = attempts.get(key);
  if (!entry) return;
  const elapsed = Date.now() - entry.first;
  if (elapsed > WINDOW_MS) {
    attempts.delete(key);
    return;
  }
  if (entry.count >= MAX_FAILURES) {
    const minutes = Math.ceil((WINDOW_MS - elapsed) / 60_000);
    throw new HttpError(429, `Trop de tentatives. Réessayez dans ${minutes} min.`);
  }
}

export function recordLoginFailure(key: string): void {
  const entry = attempts.get(key);
  if (!entry || Date.now() - entry.first > WINDOW_MS) attempts.set(key, { count: 1, first: Date.now() });
  else entry.count += 1;
}

export function clearLoginFailures(key: string): void {
  attempts.delete(key);
}
