import { z } from 'zod';
import { getCampaign } from '@/lib/campaigns';
import { api, readBody } from '@/lib/http';
import { defaultTransport, sendCampaignMail } from '@/lib/mailer';
import { findRow, getTable, sampleRow } from '@/lib/recipients';

const schema = z.object({
  to: z.email('adresse invalide'),
  rowId: z.string().optional(),
});

/** E-mail de test (objet préfixé [TEST]) ; ne modifie pas la colonne sent. */
export const POST = api<{ id: string }>(async (req, { id }) => {
  const { to, rowId } = schema.parse(await readBody(req));
  const campaign = await getCampaign(id);
  const table = await getTable(campaign.table);
  const row = (rowId ? await findRow(table, rowId) : null) ?? (await sampleRow(table));
  const transport = await defaultTransport();
  try {
    return await sendCampaignMail(transport, campaign, row, to, '[TEST] ');
  } finally {
    transport.close();
  }
}, { role: 'editor' });
