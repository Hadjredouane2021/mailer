import { z } from 'zod';
import { HttpError, api, readBody } from '@/lib/http';
import { isTableBusy } from '@/lib/jobs';
import { getTable, listRecipients, setSent } from '@/lib/recipients';

const listSchema = z.object({
  q: z.string().trim().max(200).optional(),
  status: z.enum(['all', 'sent', 'pending']).default('all'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(500).default(50),
});

export const GET = api<{ table: string }>(async (req, { table }) => {
  const opts = listSchema.parse(Object.fromEntries(new URL(req.url).searchParams));
  return listRecipients(await getTable(table), opts);
});

const patchSchema = z.object({
  ids: z
    .array(z.union([z.string(), z.number()]).transform(String))
    .min(1)
    .max(1000),
  sent: z.boolean(),
});

/** Marquer des destinataires comme envoyés / à renvoyer. */
export const PATCH = api<{ table: string }>(async (req, { table }) => {
  const info = await getTable(table);
  if (isTableBusy(info.name)) throw new HttpError(409, 'Un envoi est en cours sur cette table.');
  const { ids, sent } = patchSchema.parse(await readBody(req));
  return { updated: await setSent(info, ids, sent) };
}, { role: 'editor' });
