import { api } from '@/lib/http';
import { isTableBusy } from '@/lib/jobs';
import { listRecipientTables } from '@/lib/recipients';

export const GET = api(async () => {
  const tables = await listRecipientTables();
  return tables.map((t) => ({ ...t, busy: isTableBusy(t.name) }));
});
