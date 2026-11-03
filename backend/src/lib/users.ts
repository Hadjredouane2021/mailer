import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'crypto';
import { promisify } from 'util';
import { z } from 'zod';
import { HttpError } from './errors';
import { readJson, writeJson } from './store';

const scrypt = promisify(scryptCallback) as (password: string, salt: Buffer, keylen: number) => Promise<Buffer>;

export const roles = ['admin', 'editor', 'viewer'] as const;
export type Role = (typeof roles)[number];

const RANK: Record<Role, number> = { viewer: 0, editor: 1, admin: 2 };

export function hasRole(role: Role, required: Role): boolean {
  return RANK[role] >= RANK[required];
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
  active: boolean;
  passwordHash: string;
  /** Incrémenté à chaque changement de mot de passe / désactivation : invalide les sessions ouvertes. */
  tokenVersion: number;
  createdAt: string;
  updatedAt: string;
  lastLoginAt: string | null;
}

export type PublicUser = Omit<User, 'passwordHash' | 'tokenVersion'>;

export function publicUser(user: User): PublicUser {
  const { passwordHash: _hash, tokenVersion: _version, ...rest } = user;
  return rest;
}

// ── Mots de passe (scrypt, sel aléatoire)

const KEY_LENGTH = 64;

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const hash = await scrypt(password, salt, KEY_LENGTH);
  return `scrypt:${salt.toString('hex')}:${hash.toString('hex')}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, saltHex, hashHex] = stored.split(':');
  if (scheme !== 'scrypt' || !saltHex || !hashHex) return false;
  const expected = Buffer.from(hashHex, 'hex');
  const actual = await scrypt(password, Buffer.from(saltHex, 'hex'), expected.length);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

// Calcul factice quand l'e-mail est inconnu : même durée de réponse que pour un compte existant.
const DUMMY_HASH = `scrypt:${'0'.repeat(32)}:${'0'.repeat(KEY_LENGTH * 2)}`;

// ── Validation

const emailSchema = z.string().trim().toLowerCase().pipe(z.email('adresse invalide'));
const nameSchema = z.string().trim().min(1, 'obligatoire').max(120);
export const passwordSchema = z.string().min(8, '8 caractères minimum').max(200);

export const createUserSchema = z.object({
  name: nameSchema,
  email: emailSchema,
  role: z.enum(roles).default('viewer'),
  password: passwordSchema,
  active: z.boolean().default(true),
});

export const updateUserSchema = z.object({
  name: nameSchema.optional(),
  email: emailSchema.optional(),
  role: z.enum(roles).optional(),
  active: z.boolean().optional(),
  password: passwordSchema.optional(),
});

export const profileSchema = z.object({
  name: nameSchema.optional(),
  email: emailSchema.optional(),
});

// ── Stockage (data/users.json), gardé en mémoire : lu à chaque requête authentifiée

const FILE = 'users.json';
const cache = globalThis as unknown as { __maillerUsers?: User[] };

async function load(): Promise<User[]> {
  cache.__maillerUsers ??= await readJson<User[]>(FILE, []);
  return cache.__maillerUsers;
}

// Lecture-modification-écriture : une seule mutation à la fois, cache remplacé après écriture.
let queue: Promise<unknown> = Promise.resolve();
function mutate<T>(fn: (all: User[]) => { next: User[]; result: T }): Promise<T> {
  const run = queue.then(async () => {
    const { next, result } = fn(await load());
    await writeJson(FILE, next);
    cache.__maillerUsers = next;
    return result;
  });
  queue = run.catch(() => undefined);
  return run;
}

function newId(): string {
  return `u_${randomBytes(6).toString('hex')}`;
}

const activeAdmins = (all: User[]) => all.filter((u) => u.role === 'admin' && u.active).length;

function assertEmailFree(all: User[], email: string, exceptId?: string): void {
  if (all.some((u) => u.email === email && u.id !== exceptId)) {
    throw new HttpError(409, `Un utilisateur utilise déjà l’adresse ${email}.`);
  }
}

function requireUser(all: User[], id: string): { user: User; index: number } {
  const index = all.findIndex((u) => u.id === id);
  if (index === -1) throw new HttpError(404, 'Utilisateur introuvable.');
  return { user: all[index], index };
}

export async function countUsers(): Promise<number> {
  return (await load()).length;
}

export async function listUsers(): Promise<PublicUser[]> {
  return [...(await load())].sort((a, b) => a.createdAt.localeCompare(b.createdAt)).map(publicUser);
}

export async function getUser(id: string): Promise<User | null> {
  return (await load()).find((u) => u.id === id) ?? null;
}

export async function createUser(input: unknown, options: { firstAdmin?: boolean } = {}): Promise<User> {
  const data = createUserSchema.parse(input);
  const passwordHash = await hashPassword(data.password);
  const now = new Date().toISOString();
  return mutate((all) => {
    if (options.firstAdmin && all.length > 0) {
      throw new HttpError(409, 'Le compte administrateur existe déjà : connectez-vous.');
    }
    assertEmailFree(all, data.email);
    const user: User = {
      id: newId(),
      name: data.name,
      email: data.email,
      role: options.firstAdmin ? 'admin' : data.role,
      active: options.firstAdmin ? true : data.active,
      passwordHash,
      tokenVersion: 0,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: null,
    };
    return { next: [...all, user], result: user };
  });
}

/** Modification par un administrateur (page Utilisateurs). */
export async function updateUser(id: string, input: unknown, actorId: string): Promise<User> {
  const patch = updateUserSchema.parse(input);
  const passwordHash = patch.password ? await hashPassword(patch.password) : null;
  return mutate((all) => {
    const { user, index } = requireUser(all, id);
    const self = id === actorId;
    if (self && patch.role !== undefined && patch.role !== user.role) {
      throw new HttpError(409, 'Vous ne pouvez pas modifier votre propre rôle.');
    }
    if (self && patch.active === false) throw new HttpError(409, 'Vous ne pouvez pas désactiver votre propre compte.');
    if (self && passwordHash) throw new HttpError(409, 'Changez votre mot de passe depuis « Mon compte ».');

    const losesAdmin = (patch.role !== undefined && patch.role !== 'admin') || patch.active === false;
    if (user.role === 'admin' && user.active && losesAdmin && activeAdmins(all) <= 1) {
      throw new HttpError(409, 'Il doit rester au moins un administrateur actif.');
    }
    if (patch.email) assertEmailFree(all, patch.email, id);

    const revoke = passwordHash !== null || (patch.active === false && user.active);
    const updated: User = {
      ...user,
      name: patch.name ?? user.name,
      email: patch.email ?? user.email,
      role: patch.role ?? user.role,
      active: patch.active ?? user.active,
      passwordHash: passwordHash ?? user.passwordHash,
      tokenVersion: revoke ? user.tokenVersion + 1 : user.tokenVersion,
      updatedAt: new Date().toISOString(),
    };
    const next = [...all];
    next[index] = updated;
    return { next, result: updated };
  });
}

export function deleteUser(id: string, actorId: string): Promise<void> {
  return mutate((all) => {
    const { user } = requireUser(all, id);
    if (id === actorId) throw new HttpError(409, 'Vous ne pouvez pas supprimer votre propre compte.');
    if (user.role === 'admin' && user.active && activeAdmins(all) <= 1) {
      throw new HttpError(409, 'Il doit rester au moins un administrateur actif.');
    }
    return { next: all.filter((u) => u.id !== id), result: undefined };
  });
}

/** « Mon compte » : nom et adresse e-mail. */
export function updateProfile(id: string, input: unknown): Promise<User> {
  const patch = profileSchema.parse(input);
  return mutate((all) => {
    const { user, index } = requireUser(all, id);
    if (patch.email) assertEmailFree(all, patch.email, id);
    const updated: User = {
      ...user,
      name: patch.name ?? user.name,
      email: patch.email ?? user.email,
      updatedAt: new Date().toISOString(),
    };
    const next = [...all];
    next[index] = updated;
    return { next, result: updated };
  });
}

/** Changement de son propre mot de passe : les autres sessions sont fermées. */
export async function changePassword(id: string, current: string, nextPassword: string): Promise<User> {
  const user = await getUser(id);
  if (!user) throw new HttpError(404, 'Utilisateur introuvable.');
  if (!(await verifyPassword(current, user.passwordHash))) {
    throw new HttpError(400, 'Mot de passe actuel incorrect.');
  }
  const passwordHash = await hashPassword(passwordSchema.parse(nextPassword));
  return mutate((all) => {
    const { user: fresh, index } = requireUser(all, id);
    const updated: User = {
      ...fresh,
      passwordHash,
      tokenVersion: fresh.tokenVersion + 1,
      updatedAt: new Date().toISOString(),
    };
    const next = [...all];
    next[index] = updated;
    return { next, result: updated };
  });
}

export type CredentialCheck = { ok: true; user: User } | { ok: false; disabled: boolean };

export async function checkCredentials(email: string, password: string): Promise<CredentialCheck> {
  const user = (await load()).find((u) => u.email === email.trim().toLowerCase());
  const valid = await verifyPassword(password, user?.passwordHash ?? DUMMY_HASH);
  if (!user || !valid) return { ok: false, disabled: false };
  if (!user.active) return { ok: false, disabled: true };
  const now = new Date().toISOString();
  const updated = await mutate((all) => {
    const { user: fresh, index } = requireUser(all, user.id);
    const next = [...all];
    next[index] = { ...fresh, lastLoginAt: now };
    return { next, result: next[index] };
  });
  return { ok: true, user: updated };
}
