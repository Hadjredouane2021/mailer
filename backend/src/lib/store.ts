import { promises as fs } from 'fs';
import path from 'path';

/** Données locales de l'API (campagnes, réglages, historique, images). */
export const DATA_DIR = process.env.MAILLER_DATA_DIR || path.join(process.cwd(), 'data');

const writeQueues = new Map<string, Promise<void>>();

export function dataPath(...parts: string[]): string {
  return path.join(DATA_DIR, ...parts);
}

export async function readJson<T>(file: string, fallback: T): Promise<T> {
  try {
    const raw = await fs.readFile(dataPath(file), 'utf8');
    return raw.trim() === '' ? fallback : (JSON.parse(raw) as T);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return fallback;
    throw error;
  }
}

/** Écriture atomique (fichier temporaire + renommage), sérialisée par fichier. */
export function writeJson(file: string, data: unknown): Promise<void> {
  const target = dataPath(file);
  const previous = writeQueues.get(target) ?? Promise.resolve();
  const next = previous
    .catch(() => undefined)
    .then(async () => {
      await fs.mkdir(path.dirname(target), { recursive: true });
      const tmp = `${target}.${process.pid}.tmp`;
      await fs.writeFile(tmp, JSON.stringify(data, null, 2), 'utf8');
      await renameWithRetry(tmp, target);
    });
  writeQueues.set(target, next);
  return next;
}

export async function appendLines(file: string, lines: string[]): Promise<void> {
  if (lines.length === 0) return;
  const target = dataPath(file);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.appendFile(target, lines.join('\n') + '\n', 'utf8');
}

export async function readLines(file: string): Promise<string[]> {
  try {
    const raw = await fs.readFile(dataPath(file), 'utf8');
    return raw.split('\n').filter((line) => line.trim() !== '');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
}

// Sous Windows, un antivirus peut verrouiller brièvement le fichier cible.
async function renameWithRetry(from: string, to: string, attempts = 5): Promise<void> {
  for (let i = 1; ; i++) {
    try {
      await fs.rename(from, to);
      return;
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (i >= attempts || (code !== 'EPERM' && code !== 'EBUSY')) throw error;
      await new Promise((resolve) => setTimeout(resolve, 50 * i));
    }
  }
}
