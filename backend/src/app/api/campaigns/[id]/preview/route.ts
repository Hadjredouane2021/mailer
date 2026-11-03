import { getCampaign } from '@/lib/campaigns';
import { api, requestOrigin } from '@/lib/http';
import { getTable, sampleRow, type Row } from '@/lib/recipients';
import { renderMessage } from '@/lib/render';

/** Aperçu HTML brut (ouvrable dans un navigateur avec ?token=…). */
export const GET = api<{ id: string }>(async (req, { id }) => {
  const campaign = await getCampaign(id);
  let row: Row | null = null;
  try {
    row = await sampleRow(await getTable(campaign.table));
  } catch {
    row = null;
  }
  const message = renderMessage(campaign, row, { kind: 'preview', origin: requestOrigin(req) });
  return new Response(message.html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
});
