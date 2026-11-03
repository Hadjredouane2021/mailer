import { HttpError, api } from '@/lib/http';
import { isTableBusy } from '@/lib/jobs';
import { getTable, resetTable } from '@/lib/recipients';

/** Remet toute la table à sent=0 (bouton « reset sent » d'admin.php). */
export const POST = api<{ table: string }>(async (_req, { table }) => {
  const info = await getTable(table);
  if (isTableBusy(info.name)) throw new HttpError(409, 'Un envoi est en cours sur cette table.');
  return { updated: await resetTable(info) };
}, { role: 'editor' });
