import { randomBytes } from 'crypto';
import { promises as fs } from 'fs';
import { z } from 'zod';
import { HttpError } from './errors';
import { assertAllowedSender, getSettings } from './settings';
import { dataPath, readJson, writeJson } from './store';

const FILE = 'campaigns.json';

export const campaignStatuses = ['draft', 'active', 'archived'] as const;

export const campaignSchema = z.object({
  name: z.string().trim().min(1, 'obligatoire').max(120),
  description: z.string().trim().max(500).default(''),
  status: z.enum(campaignStatuses).default('draft'),
  table: z.string().trim().regex(/^[A-Za-z0-9_]+$/, 'nom de table invalide'),
  fromEmail: z.email('adresse invalide'),
  fromName: z.string().trim().min(1, 'obligatoire').max(200),
  replyTo: z.union([z.email('adresse invalide'), z.literal('')]).default(''),
  subject: z.string().trim().min(1, 'obligatoire').max(300),
  bodyHtml: z.string().min(1, 'obligatoire'),
  altBody: z.string().default(''),
  batchSize: z.coerce.number().int().min(1).max(500),
  pauseSeconds: z.coerce.number().int().min(0).max(3600),
});

export type CampaignInput = z.infer<typeof campaignSchema>;

export interface Campaign extends CampaignInput {
  id: string;
  createdAt: string;
  updatedAt: string;
  lastRunAt?: string | null;
  source?: string;
  /** Nom de l'utilisateur à l'origine de la dernière modification. */
  updatedBy?: string | null;
}

/** Premier lancement : reprise des campagnes du projet PHP (data/seed/campaigns.json). */
async function load(): Promise<Campaign[]> {
  const existing = await readJson<Campaign[] | null>(FILE, null);
  if (existing) return existing;
  let seed: Campaign[] = [];
  try {
    seed = JSON.parse(await fs.readFile(dataPath('seed', 'campaigns.json'), 'utf8')) as Campaign[];
  } catch {
    seed = [];
  }
  await writeJson(FILE, seed);
  return seed;
}

// Lecture-modification-écriture du fichier : une seule mutation à la fois.
let queue: Promise<unknown> = Promise.resolve();
function exclusive<T>(fn: (all: Campaign[]) => Promise<T>): Promise<T> {
  const run = queue.then(async () => fn(await load()));
  queue = run.catch(() => undefined);
  return run;
}

function newId(): string {
  return `c_${randomBytes(5).toString('hex')}`;
}

export async function listCampaigns(): Promise<Campaign[]> {
  const all = await load();
  return [...all].sort((a, b) => (b.updatedAt ?? '').localeCompare(a.updatedAt ?? ''));
}

export async function getCampaign(id: string): Promise<Campaign> {
  const campaign = (await load()).find((c) => c.id === id);
  if (!campaign) throw new HttpError(404, 'Campagne introuvable.');
  return campaign;
}

export async function createCampaign(input: unknown, by: string | null = null): Promise<Campaign> {
  const { defaults } = await getSettings();
  const data = campaignSchema.parse({
    fromEmail: defaults.fromEmail,
    fromName: defaults.fromName,
    batchSize: defaults.batchSize,
    pauseSeconds: defaults.pauseSeconds,
    ...(input as object),
  });
  await assertAllowedSender(data.fromEmail);
  const now = new Date().toISOString();
  const campaign: Campaign = { ...data, id: newId(), createdAt: now, updatedAt: now, lastRunAt: null, updatedBy: by };
  return exclusive(async (all) => {
    await writeJson(FILE, [...all, campaign]);
    return campaign;
  });
}

export async function updateCampaign(id: string, patch: unknown, by: string | null = null): Promise<Campaign> {
  const data = campaignSchema.partial().parse(patch);
  await assertAllowedSender(data.fromEmail);
  return exclusive(async (all) => {
    const index = all.findIndex((c) => c.id === id);
    if (index === -1) throw new HttpError(404, 'Campagne introuvable.');
    const updated: Campaign = { ...all[index], ...data, updatedAt: new Date().toISOString(), updatedBy: by };
    all[index] = updated;
    await writeJson(FILE, all);
    return updated;
  });
}

export function markRun(id: string): Promise<void> {
  return exclusive(async (all) => {
    const campaign = all.find((c) => c.id === id);
    if (!campaign) return;
    campaign.lastRunAt = new Date().toISOString();
    await writeJson(FILE, all);
  });
}

export function duplicateCampaign(id: string, by: string | null = null): Promise<Campaign> {
  return exclusive(async (all) => {
    const source = all.find((c) => c.id === id);
    if (!source) throw new HttpError(404, 'Campagne introuvable.');
    const now = new Date().toISOString();
    const copy: Campaign = {
      ...source,
      id: newId(),
      name: `${source.name} (copie)`,
      status: 'draft',
      createdAt: now,
      updatedAt: now,
      lastRunAt: null,
      source: undefined,
      updatedBy: by,
    };
    await writeJson(FILE, [...all, copy]);
    return copy;
  });
}

export function deleteCampaign(id: string): Promise<void> {
  return exclusive(async (all) => {
    if (!all.some((c) => c.id === id)) throw new HttpError(404, 'Campagne introuvable.');
    await writeJson(
      FILE,
      all.filter((c) => c.id !== id),
    );
  });
}
