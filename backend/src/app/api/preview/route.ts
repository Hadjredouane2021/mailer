import { z } from 'zod';
import { api, readBody, requestOrigin } from '@/lib/http';
import { findRow, getTable, sampleRow, type Row } from '@/lib/recipients';
import { renderMessage } from '@/lib/render';

const schema = z.object({
  subject: z.string().default(''),
  bodyHtml: z.string().default(''),
  altBody: z.string().default(''),
  table: z.string().optional(),
  rowId: z.string().optional(),
});

/** Rendu du brouillon de l'éditeur avec un destinataire réel de la table. */
export const POST = api(async (req) => {
  const input = schema.parse(await readBody(req));
  let row: Row | null = null;
  if (input.table) {
    try {
      const table = await getTable(input.table);
      row = (input.rowId ? await findRow(table, input.rowId) : null) ?? (await sampleRow(table));
    } catch {
      row = null;
    }
  }
  const message = renderMessage(input, row, { kind: 'preview', origin: requestOrigin(req) });
  return { subject: message.subject, html: message.html, text: message.text, sample: row };
});
