import { api } from '@/lib/http';
import { getJob } from '@/lib/jobs';

/** État d'un envoi + journal depuis l'entrée ?since=n (suivi incrémental). */
export const GET = api<{ id: string }>(async (req, { id }) => {
  const since = Number(new URL(req.url).searchParams.get('since') ?? 0);
  return getJob(id, Number.isFinite(since) && since > 0 ? since : 0);
});
