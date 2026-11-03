import { NextResponse } from 'next/server';
import { ZodError } from 'zod';
import { principalFromToken, type Principal } from './auth';
import { HttpError } from './errors';
import { hasRole, type Role } from './users';

export { HttpError } from './errors';
export type { Principal } from './auth';

type RouteContext<P> = { params: Promise<P> };
type Handler<P> = (req: Request, params: P, auth: Principal) => Promise<unknown>;

const ANONYMOUS: Principal = { id: 'anonymous', name: '', email: '', role: 'viewer', service: false };

const FORBIDDEN: Record<Role, string> = {
  viewer: 'Accès refusé.',
  editor: 'Action réservée aux éditeurs et aux administrateurs.',
  admin: 'Action réservée aux administrateurs.',
};

/**
 * Enveloppe commune des routes : authentification, contrôle du rôle, JSON, erreurs.
 * Par défaut une route exige un utilisateur connecté (rôle « viewer » ou plus).
 * Un handler peut renvoyer un objet (sérialisé en JSON) ou une Response brute.
 */
export function api<P = Record<string, never>>(fn: Handler<P>, options: { public?: boolean; role?: Role } = {}) {
  return async (req: Request, ctx: RouteContext<P>): Promise<Response> => {
    try {
      const auth = options.public ? ANONYMOUS : await authorize(req, options.role ?? 'viewer');
      const params = ctx?.params ? await ctx.params : ({} as P);
      const result = await fn(req, params, auth);
      if (result instanceof Response) return result;
      return NextResponse.json(result ?? { ok: true });
    } catch (error) {
      return errorResponse(error);
    }
  };
}

async function authorize(req: Request, role: Role): Promise<Principal> {
  const header = req.headers.get('authorization') ?? '';
  // ?token= : utile pour ouvrir un aperçu HTML directement dans le navigateur
  const provided = header.startsWith('Bearer ')
    ? header.slice(7).trim()
    : (new URL(req.url).searchParams.get('token') ?? '').trim();
  if (provided === '') throw new HttpError(401, 'Authentification requise.');

  const principal = await principalFromToken(provided);
  if (!principal) throw new HttpError(401, 'Session expirée ou invalide : reconnectez-vous.');
  if (!hasRole(principal.role, role)) throw new HttpError(403, FORBIDDEN[role]);
  return principal;
}

const DB_ERRORS: Record<string, string> = {
  ECONNREFUSED: 'Serveur MySQL injoignable (est-il démarré ?).',
  ER_ACCESS_DENIED_ERROR: 'Accès MySQL refusé : vérifiez utilisateur et mot de passe.',
  ER_BAD_DB_ERROR: 'Base de données introuvable.',
  ER_NO_SUCH_TABLE: 'Table introuvable.',
};

function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return NextResponse.json({ error: error.message }, { status: error.status });
  }
  if (error instanceof ZodError) {
    const issue = error.issues[0];
    const field = issue?.path.join('.') || 'requête';
    return NextResponse.json({ error: `${field} : ${issue?.message ?? 'valeur invalide'}` }, { status: 400 });
  }
  const code = (error as { code?: string })?.code;
  if (code && DB_ERRORS[code]) {
    return NextResponse.json({ error: DB_ERRORS[code] }, { status: 502 });
  }
  console.error(error);
  const message = error instanceof Error ? error.message : 'Erreur interne.';
  return NextResponse.json({ error: message }, { status: 500 });
}

/**
 * Origine vue par le navigateur (en-tête Host), pour les URLs absolues renvoyées au client.
 * req.url donne l'adresse d'écoute du serveur (ex. 0.0.0.0), injoignable depuis un navigateur.
 */
export function requestOrigin(req: Request): string {
  const url = new URL(req.url);
  const host = req.headers.get('x-forwarded-host') ?? req.headers.get('host');
  const proto = req.headers.get('x-forwarded-proto') ?? url.protocol.replace(/:$/, '');
  return host ? `${proto}://${host}` : url.origin;
}

export async function readBody<T = unknown>(req: Request): Promise<T> {
  try {
    return (await req.json()) as T;
  } catch {
    throw new HttpError(400, 'Corps JSON invalide.');
  }
}
