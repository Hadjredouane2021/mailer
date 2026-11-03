import type { RowDataPacket } from 'mysql2/promise';
import { escapeLike, execute, ident, query } from './db';
import { HttpError } from './errors';
import { getSettings } from './settings';

/** Même ordre de détection que send.php / index.php. */
const ID_CANDIDATES = ['id', 'id_participant', 'participant_id', 'participantid', 'uuid', 'email'];

export interface TableInfo {
  name: string;
  columns: string[];
  idColumn: string;
  total: number;
  sent: number;
  pending: number;
}

export type Row = Record<string, string | number | null>;

export type RecipientStatus = 'all' | 'sent' | 'pending';

async function columnsByTable(): Promise<Map<string, string[]>> {
  const { db } = await getSettings();
  const rows = await query(
    `SELECT TABLE_NAME AS t, COLUMN_NAME AS c
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = ?
      ORDER BY TABLE_NAME, ORDINAL_POSITION`,
    [db.database],
  );
  const map = new Map<string, string[]>();
  for (const row of rows) {
    const table = String(row.t);
    if (!map.has(table)) map.set(table, []);
    map.get(table)!.push(String(row.c));
  }
  return map;
}

/** Une table de destinataires = une table avec les colonnes `email` et `sent`. */
function isRecipientTable(columns: string[]): boolean {
  return columns.includes('email') && columns.includes('sent');
}

function detectIdColumn(columns: string[]): string {
  return ID_CANDIDATES.find((c) => columns.includes(c)) ?? 'email';
}

async function withCounts(tables: Array<[string, string[]]>): Promise<TableInfo[]> {
  if (tables.length === 0) return [];
  const sql = tables
    .map(
      ([name]) =>
        `SELECT ? AS t, COUNT(*) AS total, COALESCE(SUM(sent = '1'), 0) AS sent, COALESCE(SUM(sent = '0'), 0) AS pending FROM ${ident(name)}`,
    )
    .join(' UNION ALL ');
  const rows = await query(sql, tables.map(([name]) => name));
  const counts = new Map(rows.map((r) => [String(r.t), r]));
  return tables.map(([name, columns]) => {
    const c = counts.get(name);
    return {
      name,
      columns,
      idColumn: detectIdColumn(columns),
      total: Number(c?.total ?? 0),
      sent: Number(c?.sent ?? 0),
      pending: Number(c?.pending ?? 0),
    };
  });
}

export async function listRecipientTables(): Promise<TableInfo[]> {
  const map = await columnsByTable();
  return withCounts([...map.entries()].filter(([, columns]) => isRecipientTable(columns)));
}

export async function getTable(name: string): Promise<TableInfo> {
  ident(name);
  const columns = (await columnsByTable()).get(name);
  if (!columns || !isRecipientTable(columns)) {
    throw new HttpError(404, `La table « ${name} » n’existe pas ou n’a pas de colonnes email/sent.`);
  }
  const [info] = await withCounts([[name, columns]]);
  return info;
}

function normalizeRow(row: RowDataPacket): Row {
  const out: Row = {};
  for (const [key, value] of Object.entries(row)) {
    if (value === null || value === undefined) out[key] = null;
    else if (typeof value === 'number' || typeof value === 'string') out[key] = value;
    else if (Buffer.isBuffer(value)) out[key] = value.toString('utf8');
    else out[key] = String(value);
  }
  return out;
}

export async function listRecipients(
  table: TableInfo,
  opts: { q?: string; status?: RecipientStatus; page: number; pageSize: number },
) {
  const where: string[] = [];
  const params: unknown[] = [];
  if (opts.q) {
    // Recherche dans toutes les colonnes (e-mail, nom, société…) ; CONCAT_WS ignore les NULL.
    where.push(`CONCAT_WS(' ', ${table.columns.map(ident).join(', ')}) LIKE ?`);
    params.push(`%${escapeLike(opts.q)}%`);
  }
  if (opts.status === 'sent') where.push("`sent` = '1'");
  if (opts.status === 'pending') where.push("`sent` = '0'");
  const whereSql = where.length > 0 ? ` WHERE ${where.join(' AND ')}` : '';

  const t = ident(table.name);
  const [{ c }] = await query(`SELECT COUNT(*) AS c FROM ${t}${whereSql}`, params);
  const rows = await query(
    `SELECT * FROM ${t}${whereSql} ORDER BY ${ident(table.idColumn)} DESC LIMIT ? OFFSET ?`,
    [...params, opts.pageSize, (opts.page - 1) * opts.pageSize],
  );
  return {
    table: table.name,
    columns: table.columns,
    idColumn: table.idColumn,
    total: Number(c),
    page: opts.page,
    pageSize: opts.pageSize,
    rows: rows.map(normalizeRow),
  };
}

export function setSent(table: TableInfo, rowIds: string[], sent: boolean): Promise<number> {
  if (rowIds.length === 0) return Promise.resolve(0);
  return execute(`UPDATE ${ident(table.name)} SET sent = ? WHERE ${ident(table.idColumn)} IN (?)`, [
    sent ? '1' : '0',
    rowIds,
  ]);
}

/** Équivalent du bouton « reset sent » d'admin.php. */
export function resetTable(table: TableInfo): Promise<number> {
  return execute(`UPDATE ${ident(table.name)} SET sent = '0' WHERE sent = '1'`);
}

function excludeClause(table: TableInfo, exclude: string[]): { sql: string; params: unknown[] } {
  return exclude.length > 0
    ? { sql: ` AND ${ident(table.idColumn)} NOT IN (?)`, params: [exclude] }
    : { sql: '', params: [] };
}

/** Prochain lot : lignes sent='0', hors adresses déjà en échec dans cet envoi. */
export async function fetchPending(table: TableInfo, limit: number, exclude: string[] = []): Promise<Row[]> {
  const ex = excludeClause(table, exclude);
  const rows = await query(
    `SELECT * FROM ${ident(table.name)} WHERE sent = '0'${ex.sql} ORDER BY ${ident(table.idColumn)} ASC LIMIT ?`,
    [...ex.params, limit],
  );
  return rows.map(normalizeRow);
}

export async function countPending(table: TableInfo, exclude: string[] = []): Promise<number> {
  const ex = excludeClause(table, exclude);
  const [{ c }] = await query(`SELECT COUNT(*) AS c FROM ${ident(table.name)} WHERE sent = '0'${ex.sql}`, ex.params);
  return Number(c);
}

export async function markSent(table: TableInfo, rowId: string): Promise<void> {
  await execute(`UPDATE ${ident(table.name)} SET sent = '1' WHERE ${ident(table.idColumn)} = ?`, [rowId]);
}

/** Ligne d'exemple pour l'aperçu : premier destinataire en attente, sinon le premier tout court. */
export async function sampleRow(table: TableInfo): Promise<Row | null> {
  const t = ident(table.name);
  const pending = await query(`SELECT * FROM ${t} WHERE sent = '0' LIMIT 1`);
  if (pending.length > 0) return normalizeRow(pending[0]);
  const any = await query(`SELECT * FROM ${t} LIMIT 1`);
  return any.length > 0 ? normalizeRow(any[0]) : null;
}

export async function findRow(table: TableInfo, rowId: string): Promise<Row | null> {
  const rows = await query(`SELECT * FROM ${ident(table.name)} WHERE ${ident(table.idColumn)} = ? LIMIT 1`, [rowId]);
  return rows.length > 0 ? normalizeRow(rows[0]) : null;
}

export function rowIdOf(table: TableInfo, row: Row): string {
  return String(row[table.idColumn] ?? '');
}
