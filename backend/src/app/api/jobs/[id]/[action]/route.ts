import { HttpError, api } from '@/lib/http';
import { controlJob, type JobAction } from '@/lib/jobs';

const ACTIONS: JobAction[] = ['pause', 'resume', 'cancel', 'skip'];

export const POST = api<{ id: string; action: string }>(async (_req, { id, action }) => {
  if (!ACTIONS.includes(action as JobAction)) throw new HttpError(404, 'Action inconnue.');
  return controlJob(id, action as JobAction);
}, { role: 'editor' });
