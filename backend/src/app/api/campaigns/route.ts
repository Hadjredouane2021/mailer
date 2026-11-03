import { createCampaign, listCampaigns } from '@/lib/campaigns';
import { api, readBody } from '@/lib/http';
import { activeJobs } from '@/lib/jobs';
import { listRecipientTables, type TableInfo } from '@/lib/recipients';

/** Campagnes + progression de leur table (si la base répond). */
export const GET = api(async () => {
  const campaigns = await listCampaigns();
  let tables: TableInfo[] = [];
  try {
    tables = await listRecipientTables();
  } catch {
    tables = [];
  }
  const byName = new Map(tables.map((t) => [t.name, t]));
  const running = activeJobs();
  return campaigns.map((c) => {
    const t = byName.get(c.table);
    return {
      ...c,
      bodyHtml: undefined,
      altBody: undefined,
      tableStats: t ? { total: t.total, sent: t.sent, pending: t.pending } : null,
      activeJobId: running.find((j) => j.campaignId === c.id)?.id ?? null,
    };
  });
});

export const POST = api(async (req, _params, auth) => createCampaign(await readBody(req), auth.name), {
  role: 'editor',
});
