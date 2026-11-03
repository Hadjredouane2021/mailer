import { createPool } from '@/lib/db';
import { api } from '@/lib/http';
import { dbSchema, getSettings, withStoredPassword } from '@/lib/settings';

/** Teste une connexion MySQL (réglages du formulaire, ou ceux enregistrés). */
export const POST = api(async (req) => {
  const current = await getSettings();
  const body = (await req.json().catch(() => ({}))) as { db?: unknown };
  const db = body.db ? withStoredPassword(dbSchema.parse(body.db), current.db) : current.db;
  const pool = createPool(db);
  try {
    const [rows] = await pool.query(
      `SELECT COUNT(*) AS c FROM (
         SELECT TABLE_NAME FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = ? AND COLUMN_NAME IN ('email', 'sent')
          GROUP BY TABLE_NAME HAVING COUNT(*) = 2
       ) AS recipient_tables`,
      [db.database],
    );
    const count = Number((rows as Array<{ c: number | string }>)[0]?.c ?? 0);
    return { ok: true, message: `Connexion réussie à « ${db.database} » : ${count} table(s) de destinataires.` };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : String(error) };
  } finally {
    await pool.end().catch(() => undefined);
  }
}, { role: 'admin' });
