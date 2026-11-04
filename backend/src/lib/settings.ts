import { z } from 'zod';
import { HttpError } from './errors';
import { readJson, writeJson } from './store';

export interface DbSettings {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
}

export interface SmtpSettings {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  password: string;
}

export interface Settings {
  db: DbSettings;
  smtp: SmtpSettings;
  defaults: {
    fromEmail: string;
    fromName: string;
    batchSize: number;
    pauseSeconds: number;
    /** Adresses d'expéditeur proposées (et seules acceptées) pour les campagnes. */
    senders: string[];
  };
}

/** Expéditeurs autorisés par défaut (MAIL_SENDERS dans .env.local pour en changer). */
const DEFAULT_SENDERS = ['newsletter@fma.org.ma', 'inscription@rdvdelassurance.ma', 'information@rdvdelassurance.ma'];

function normalizeSenders(list: string[], fromEmail: string): string[] {
  const clean = list.map((s) => s.trim().toLowerCase()).filter((s) => s !== '');
  return [...new Set(clean.length > 0 ? clean : [fromEmail.trim().toLowerCase()])];
}

const FILE = 'settings.json';

const cache = globalThis as unknown as { __maillerSettings?: Settings };

function int(value: string | undefined, fallback: number): number {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

/** Valeurs de .env.local : reprises de mailing_settings.json et du $mail PHP. */
function envDefaults(): Settings {
  const env = process.env;
  return {
    db: {
      host: env.DB_HOST ?? 'localhost',
      port: int(env.DB_PORT, 3306),
      user: env.DB_USER ?? 'root',
      password: env.DB_PASSWORD ?? '',
      database: env.DB_NAME ?? 'mail',
    },
    smtp: {
      host: env.SMTP_HOST ?? 'smtp-pulse.com',
      port: int(env.SMTP_PORT, 465),
      secure: (env.SMTP_SECURE ?? 'true') !== 'false',
      user: env.SMTP_USER ?? '',
      password: env.SMTP_PASSWORD ?? '',
    },
    defaults: {
      fromEmail: env.MAIL_FROM_EMAIL ?? 'newsletter@fma.org.ma',
      fromName: env.MAIL_FROM_NAME ?? 'Mailler Studio',
      batchSize: int(env.DEFAULT_BATCH_SIZE, 20),
      pauseSeconds: int(env.DEFAULT_PAUSE_SECONDS, 120),
      senders: env.MAIL_SENDERS ? env.MAIL_SENDERS.split(',') : DEFAULT_SENDERS,
    },
  };
}

export async function getSettings(): Promise<Settings> {
  if (cache.__maillerSettings) return cache.__maillerSettings;
  const base = envDefaults();
  const saved = await readJson<Partial<Settings>>(FILE, {});
  const merged: Settings = {
    db: { ...base.db, ...saved.db },
    smtp: { ...base.smtp, ...saved.smtp },
    defaults: { ...base.defaults, ...saved.defaults },
  };
  merged.defaults.senders = normalizeSenders(merged.defaults.senders, merged.defaults.fromEmail);
  cache.__maillerSettings = merged;
  return merged;
}

const identifier = z.string().trim().regex(/^[A-Za-z0-9_]+$/, 'caractères autorisés : lettres, chiffres, _');

export const dbSchema = z.object({
  host: z.string().trim().min(1),
  port: z.coerce.number().int().min(1).max(65535),
  user: z.string().trim().min(1),
  password: z.string().optional(),
  database: identifier,
});

export const smtpSchema = z.object({
  host: z.string().trim().min(1),
  port: z.coerce.number().int().min(1).max(65535),
  secure: z.boolean(),
  user: z.string().trim().min(1),
  password: z.string().optional(),
});

export const settingsPatchSchema = z.object({
  db: dbSchema.optional(),
  smtp: smtpSchema.optional(),
  defaults: z
    .object({
      fromEmail: z.email(),
      fromName: z.string().trim().min(1),
      batchSize: z.coerce.number().int().min(1).max(500),
      pauseSeconds: z.coerce.number().int().min(0).max(3600),
      senders: z.array(z.email('adresse invalide')).min(1, 'au moins une adresse').max(30).optional(),
    })
    .optional(),
});

/** Un mot de passe vide ou absent conserve celui déjà enregistré. */
export function withStoredPassword<T extends { password?: string }>(next: T, current: { password: string }) {
  return { ...next, password: next.password ? next.password : current.password };
}

export async function updateSettings(patch: z.infer<typeof settingsPatchSchema>): Promise<Settings> {
  const current = await getSettings();
  const next: Settings = {
    db: patch.db ? withStoredPassword(patch.db, current.db) : current.db,
    smtp: patch.smtp ? withStoredPassword(patch.smtp, current.smtp) : current.smtp,
    defaults: patch.defaults ? { ...current.defaults, ...patch.defaults } : current.defaults,
  };
  next.defaults.senders = normalizeSenders(next.defaults.senders, next.defaults.fromEmail);
  if (!next.defaults.senders.includes(next.defaults.fromEmail.trim().toLowerCase())) {
    throw new HttpError(400, 'L’expéditeur par défaut doit faire partie des adresses autorisées.');
  }
  await writeJson(FILE, next);
  cache.__maillerSettings = next;
  return next;
}

/** Refuse une adresse d'expéditeur hors de la liste autorisée. */
export async function assertAllowedSender(fromEmail: string | undefined): Promise<void> {
  if (fromEmail === undefined) return;
  const { senders } = (await getSettings()).defaults;
  if (!senders.includes(fromEmail.trim().toLowerCase())) {
    throw new HttpError(400, `Expéditeur non autorisé : choisissez ${senders.join(' ou ')}.`);
  }
}

/** Version sans secrets, renvoyée à l'app. */
export function publicSettings(settings: Settings) {
  const { password: dbPassword, ...db } = settings.db;
  const { password: smtpPassword, ...smtp } = settings.smtp;
  return {
    db: { ...db, hasPassword: dbPassword !== '' },
    smtp: { ...smtp, hasPassword: smtpPassword !== '' },
    defaults: settings.defaults,
  };
}
