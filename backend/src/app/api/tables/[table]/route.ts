import { api } from '@/lib/http';
import { isTableBusy } from '@/lib/jobs';
import { getTable } from '@/lib/recipients';

export const GET = api<{ table: string }>(async (_req, { table }) => {
  const info = await getTable(table);
  return { ...info, busy: isTableBusy(info.name) };
});
