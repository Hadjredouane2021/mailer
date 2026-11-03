import { deleteCampaign, getCampaign, updateCampaign } from '@/lib/campaigns';
import { HttpError, api, readBody } from '@/lib/http';
import { activeJobs } from '@/lib/jobs';

export const GET = api<{ id: string }>(async (_req, { id }) => getCampaign(id));

export const PUT = api<{ id: string }>(
  async (req, { id }, auth) => updateCampaign(id, await readBody(req), auth.name),
  { role: 'editor' },
);

export const DELETE = api<{ id: string }>(async (_req, { id }) => {
  if (activeJobs().some((j) => j.campaignId === id)) {
    throw new HttpError(409, 'Impossible de supprimer une campagne en cours d’envoi.');
  }
  await deleteCampaign(id);
  return { ok: true };
}, { role: 'editor' });
