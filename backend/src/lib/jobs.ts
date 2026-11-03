import { randomBytes } from 'crypto';
import type { Transporter } from 'nodemailer';
import { getCampaign, markRun, type Campaign } from './campaigns';
import { HttpError } from './errors';
import { defaultTransport, sendCampaignMail } from './mailer';
import { countPending, fetchPending, getTable, markSent, rowIdOf, type TableInfo } from './recipients';
import { appendLines, readJson, readLines, writeJson } from './store';

export type JobStatus = 'running' | 'waiting' | 'paused' | 'completed' | 'cancelled' | 'failed';
export type JobAction = 'pause' | 'resume' | 'cancel' | 'skip';

export interface JobSummary {
  id: string;
  campaignId: string;
  campaignName: string;
  table: string;
  subject: string;
  status: JobStatus;
  createdAt: string;
  finishedAt: string | null;
  batchSize: number;
  pauseSeconds: number;
  batch: number;
  sent: number;
  failed: number;
  pendingAtStart: number;
  remaining: number;
  nextBatchAt: string | null;
  error: string | null;
  logCount: number;
  /** Nom de l'utilisateur qui a lancé l'envoi. */
  startedBy?: string | null;
}

export interface JobLog {
  i: number;
  at: string;
  batch: number;
  email: string;
  rowId: string;
  ok: boolean;
  message: string;
}

interface JobRuntime {
  summary: JobSummary;
  log: JobLog[];
  unflushed: JobLog[];
  failedIds: Set<string>;
  paused: boolean;
  cancelled: boolean;
  wake?: () => void;
}

const JOBS_FILE = 'jobs.json';
const DAILY_FILE = 'daily.json';
const MAX_HISTORY = 300;
/** Au-delà, on considère que le SMTP est en panne (auth, quota…) et on arrête. */
const MAX_CONSECUTIVE_FAILURES = 5;

type Daily = Record<string, { sent: number; failed: number }>;

interface JobsState {
  active: Map<string, JobRuntime>;
  ready?: Promise<void>;
}

// globalThis : l'état survit au rechargement à chaud des modules en dev.
const holder = globalThis as unknown as { __maillerJobs?: JobsState };
const state: JobsState = (holder.__maillerJobs ??= { active: new Map() });

const isLive = (status: JobStatus) => status === 'running' || status === 'waiting' || status === 'paused';

/** Au démarrage : un envoi resté « en cours » dans l'historique a été interrompu par un redémarrage. */
function ensureReady(): Promise<void> {
  state.ready ??= (async () => {
    const history = await readJson<JobSummary[]>(JOBS_FILE, []);
    let changed = false;
    for (const job of history) {
      if (isLive(job.status) && !state.active.has(job.id)) {
        job.status = 'failed';
        job.error = 'Interrompu : le serveur API a redémarré.';
        job.finishedAt ??= new Date().toISOString();
        job.nextBatchAt = null;
        changed = true;
      }
    }
    if (changed) await writeJson(JOBS_FILE, history);
  })();
  return state.ready;
}

let historyQueue: Promise<unknown> = Promise.resolve();
function saveSummary(summary: JobSummary): Promise<void> {
  const run = historyQueue.then(async () => {
    const history = await readJson<JobSummary[]>(JOBS_FILE, []);
    const index = history.findIndex((j) => j.id === summary.id);
    if (index === -1) history.unshift({ ...summary });
    else history[index] = { ...summary };
    await writeJson(JOBS_FILE, history.slice(0, MAX_HISTORY));
  });
  historyQueue = run.catch(() => undefined);
  return run;
}

let dailyQueue: Promise<unknown> = Promise.resolve();
function addDaily(sent: number, failed: number): Promise<void> {
  if (sent === 0 && failed === 0) return Promise.resolve();
  const run = dailyQueue.then(async () => {
    const daily = await readJson<Daily>(DAILY_FILE, {});
    const day = new Date().toISOString().slice(0, 10);
    const entry = (daily[day] ??= { sent: 0, failed: 0 });
    entry.sent += sent;
    entry.failed += failed;
    await writeJson(DAILY_FILE, daily);
  });
  dailyQueue = run.catch(() => undefined);
  return run;
}

export async function dailyStats(days: number): Promise<Array<{ date: string; sent: number; failed: number }>> {
  const daily = await readJson<Daily>(DAILY_FILE, {});
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(Date.now() - i * 86_400_000).toISOString().slice(0, 10);
    out.push({ date, sent: daily[date]?.sent ?? 0, failed: daily[date]?.failed ?? 0 });
  }
  return out;
}

async function flush(rt: JobRuntime): Promise<void> {
  const entries = rt.unflushed.splice(0);
  await appendLines(`logs/${rt.summary.id}.jsonl`, entries.map((e) => JSON.stringify(e)));
  await addDaily(entries.filter((e) => e.ok).length, entries.filter((e) => !e.ok).length);
  await saveSummary(rt.summary);
}

/** Attente interruptible (pause, annulation, « lot suivant maintenant »). */
function sleep(rt: JobRuntime, ms: number): Promise<void> {
  return new Promise((resolve) => {
    const done = () => {
      clearTimeout(timer);
      if (rt.wake === done) rt.wake = undefined;
      resolve();
    };
    const timer = setTimeout(done, ms);
    rt.wake = done;
  });
}

async function holdWhilePaused(rt: JobRuntime): Promise<void> {
  while (rt.paused && !rt.cancelled) {
    rt.summary.status = 'paused';
    rt.summary.nextBatchAt = null;
    await sleep(rt, 60_000);
  }
}

async function run(rt: JobRuntime, campaign: Campaign, table: TableInfo): Promise<void> {
  const s = rt.summary;
  let transport: Transporter | null = null;
  let consecutiveFailures = 0;
  try {
    transport = await defaultTransport(true);
    for (;;) {
      await holdWhilePaused(rt);
      if (rt.cancelled) break;

      const rows = await fetchPending(table, s.batchSize, [...rt.failedIds]);
      if (rows.length === 0) break;
      s.batch += 1;
      s.status = 'running';
      s.nextBatchAt = null;

      for (const row of rows) {
        await holdWhilePaused(rt);
        if (rt.cancelled) break;
        s.status = 'running';

        const rowId = rowIdOf(table, row);
        const email = String(row.email ?? '').trim();
        const result = email
          ? await sendCampaignMail(transport, campaign, row, email)
          : { ok: false, message: 'Adresse e-mail vide' };

        if (result.ok) {
          await markSent(table, rowId);
          s.sent += 1;
          consecutiveFailures = 0;
        } else {
          rt.failedIds.add(rowId);
          s.failed += 1;
          consecutiveFailures += 1;
        }
        const entry: JobLog = {
          i: rt.log.length,
          at: new Date().toISOString(),
          batch: s.batch,
          email,
          rowId,
          ok: result.ok,
          message: result.message,
        };
        rt.log.push(entry);
        rt.unflushed.push(entry);
        s.logCount = rt.log.length;
        s.remaining = Math.max(0, s.remaining - 1);

        if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
          throw new Error(`${MAX_CONSECUTIVE_FAILURES} échecs consécutifs, envoi arrêté. Dernière erreur : ${result.message}`);
        }
      }

      s.remaining = await countPending(table, [...rt.failedIds]);
      await flush(rt);
      if (rt.cancelled || s.remaining === 0) break;

      // Pause entre deux lots (anti-throttling), comme RDV_BATCH_PAUSE_SECONDS en PHP
      if (s.pauseSeconds > 0 && !rt.paused) {
        s.status = 'waiting';
        s.nextBatchAt = new Date(Date.now() + s.pauseSeconds * 1000).toISOString();
        await sleep(rt, s.pauseSeconds * 1000);
        s.nextBatchAt = null;
      }
    }
    s.status = rt.cancelled ? 'cancelled' : 'completed';
  } catch (error) {
    s.status = 'failed';
    s.error = error instanceof Error ? error.message : String(error);
  } finally {
    transport?.close();
    s.nextBatchAt = null;
    s.finishedAt = new Date().toISOString();
    try {
      s.remaining = await countPending(table, [...rt.failedIds]);
    } catch {
      // base indisponible : on garde la dernière valeur connue
    }
    await flush(rt).catch((e) => console.error('flush job', e));
    state.active.delete(s.id);
  }
}

export async function startJob(campaignId: string, startedBy: string | null = null): Promise<JobSummary> {
  await ensureReady();
  const campaign = await getCampaign(campaignId);
  const table = await getTable(campaign.table);

  for (const rt of state.active.values()) {
    if (rt.summary.table === table.name) {
      throw new HttpError(409, `Un envoi est déjà en cours sur la table « ${table.name} » (${rt.summary.campaignName}).`);
    }
  }
  if (table.pending === 0) {
    throw new HttpError(409, `Aucun destinataire en attente dans « ${table.name} ». Réinitialisez la table pour renvoyer.`);
  }

  const summary: JobSummary = {
    id: `j_${Date.now().toString(36)}${randomBytes(3).toString('hex')}`,
    campaignId: campaign.id,
    campaignName: campaign.name,
    table: table.name,
    subject: campaign.subject,
    status: 'running',
    createdAt: new Date().toISOString(),
    finishedAt: null,
    batchSize: campaign.batchSize,
    pauseSeconds: campaign.pauseSeconds,
    batch: 0,
    sent: 0,
    failed: 0,
    pendingAtStart: table.pending,
    remaining: table.pending,
    nextBatchAt: null,
    error: null,
    logCount: 0,
    startedBy,
  };
  const rt: JobRuntime = { summary, log: [], unflushed: [], failedIds: new Set(), paused: false, cancelled: false };
  state.active.set(summary.id, rt);
  await saveSummary(summary);
  await markRun(campaign.id);
  void run(rt, campaign, table);
  return { ...summary };
}

export function controlJob(id: string, action: JobAction): JobSummary {
  const rt = state.active.get(id);
  if (!rt) throw new HttpError(409, 'Cet envoi est terminé.');
  if (action === 'pause') rt.paused = true;
  if (action === 'resume') {
    rt.paused = false;
    rt.summary.status = 'running';
  }
  if (action === 'cancel') {
    rt.cancelled = true;
    rt.paused = false;
  }
  rt.wake?.();
  return { ...rt.summary };
}

export async function listJobs(limit = 50): Promise<JobSummary[]> {
  await ensureReady();
  const history = await readJson<JobSummary[]>(JOBS_FILE, []);
  return history.slice(0, limit).map((job) => state.active.get(job.id)?.summary ?? job);
}

export function activeJobs(): JobSummary[] {
  return [...state.active.values()].map((rt) => ({ ...rt.summary }));
}

export function isTableBusy(table: string): boolean {
  return [...state.active.values()].some((rt) => rt.summary.table === table);
}

export async function getJob(id: string, since = 0): Promise<{ job: JobSummary; log: JobLog[] }> {
  await ensureReady();
  const rt = state.active.get(id);
  if (rt) return { job: { ...rt.summary }, log: rt.log.slice(since) };

  const job = (await readJson<JobSummary[]>(JOBS_FILE, [])).find((j) => j.id === id);
  if (!job) throw new HttpError(404, 'Envoi introuvable.');
  const lines = await readLines(`logs/${id}.jsonl`);
  return { job, log: lines.slice(since).map((line) => JSON.parse(line) as JobLog) };
}
