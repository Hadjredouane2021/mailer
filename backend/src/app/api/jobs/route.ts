import { api } from '@/lib/http';
import { listJobs } from '@/lib/jobs';

export const GET = api(async (req) => {
  const limit = Number(new URL(req.url).searchParams.get('limit') ?? 50);
  return listJobs(Number.isFinite(limit) ? Math.min(Math.max(limit, 1), 300) : 50);
});
