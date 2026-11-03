import mysql, { type Pool, type RowDataPacket } from 'mysql2/promise';
import { HttpError } from './errors';
import { getSettings, type DbSettings } from './settings';

const cache = globalThis as unknown as { __maillerPool?: { key: string; pool: Pool } };

export function createPool(db: DbSettings): Pool {
  return mysql.createPool({
    host: db.host,
    port: db.port,
    user: db.user,
    password: db.password,
    database: db.database,
    charset: 'utf8mb4',
    connectionLimit: 5,
    dateStrings: true,
    supportBigNumbers: true,
    bigNumberStrings: true,
  });
}

/** Pool MySQL partagé, recréé si les réglages de connexion changent. */
export async function getPool(): Promise<Pool> {
  const { db } = await getSettings();
  const key = JSON.stringify(db);
  if (cache.__maillerPool?.key === key) return cache.__maillerPool.pool;

  const previous = cache.__maillerPool?.pool;
  const pool = createPool(db);
  cache.__maillerPool = { key, pool };
  previous?.end().catch(() => undefined);
  return pool;
}

export async function query<T extends RowDataPacket = RowDataPacket>(sql: string, params: unknown[] = []): Promise<T[]> {
  const pool = await getPool();
  const [rows] = await pool.query<T[]>(sql, params);
  return rows;
}

export async function execute(sql: string, params: unknown[] = []): Promise<number> {
  const pool = await getPool();
  const [result] = await pool.query<mysql.ResultSetHeader>(sql, params);
  return result.affectedRows;
}

/** Même règle que sanitizeIdentifier() côté PHP, puis échappement par backticks. */
export function ident(name: string): string {
  if (!/^[A-Za-z0-9_]+$/.test(name)) {
    throw new HttpError(400, `Identifiant SQL invalide : ${name}`);
  }
  return `\`${name}\``;
}

export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (c) => `\\${c}`);
}
