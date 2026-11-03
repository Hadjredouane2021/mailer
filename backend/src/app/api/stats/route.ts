import { listCampaigns } from '@/lib/campaigns';
import { api } from '@/lib/http';
import { activeJobs, dailyStats, listJobs } from '@/lib/jobs';
import { listRecipientTables } from '@/lib/recipients';

/** Données du tableau de bord. */
export const GET = api(async () => {
  const [tables, campaigns, daily, recentJobs] = await Promise.all([
    listRecipientTables(),
    listCampaigns(),
    dailyStats(14),
    listJobs(6),
  ]);
  const totals = tables.reduce(
    (acc, t) => ({ total: acc.total + t.total, sent: acc.sent + t.sent, pending: acc.pending + t.pending }),
    { total: 0, sent: 0, pending: 0 },
  );
  const byStatus = (status: string) => campaigns.filter((c) => c.status === status).length;
  return {
    totals,
    tables,
    daily,
    campaigns: {
      total: campaigns.length,
      active: byStatus('active'),
      draft: byStatus('draft'),
      archived: byStatus('archived'),
    },
    activeJobs: activeJobs(),
    recentJobs,
  };
});
