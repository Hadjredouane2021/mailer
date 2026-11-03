import { api } from '@/lib/http';
import { startJob } from '@/lib/jobs';

/** Lance l'envoi par lots côté serveur ; l'app suit la progression via /api/jobs/:id. */
export const POST = api<{ id: string }>(async (_req, { id }, auth) => startJob(id, auth.name), { role: 'editor' });
