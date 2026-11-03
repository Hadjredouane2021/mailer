import { duplicateCampaign } from '@/lib/campaigns';
import { api } from '@/lib/http';

export const POST = api<{ id: string }>(async (_req, { id }, auth) => duplicateCampaign(id, auth.name), {
  role: 'editor',
});
