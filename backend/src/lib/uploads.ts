import { randomBytes } from 'crypto';
import { promises as fs } from 'fs';
import { HttpError } from './errors';
import { dataPath } from './store';

const MAX_BYTES = 5 * 1024 * 1024;

export const MIME_BY_EXT: Record<string, string> = {
  png: 'image/png',
  jpg: 'image/jpeg',
  gif: 'image/gif',
  webp: 'image/webp',
};

export function uploadPath(name: string): string {
  if (!/^[A-Za-z0-9_.-]+$/.test(name) || name.includes('..')) {
    throw new HttpError(400, 'Nom de fichier invalide.');
  }
  return dataPath('uploads', name);
}

/** Type réel détecté à partir des premiers octets (comme finfo dans upload_image.php). */
function detectExtension(bytes: Buffer): string | null {
  if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpg';
  if (bytes.subarray(0, 4).toString('ascii') === 'GIF8') return 'gif';
  if (bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP') return 'webp';
  return null;
}

export async function saveUpload(file: File): Promise<{ name: string; url: string; size: number }> {
  if (file.size > MAX_BYTES) throw new HttpError(413, 'Fichier trop volumineux (max 5 Mo).');
  const bytes = Buffer.from(await file.arrayBuffer());
  const ext = detectExtension(bytes);
  if (!ext) throw new HttpError(415, 'Type de fichier non autorisé (PNG, JPG, GIF ou WEBP).');

  const name = `${randomBytes(12).toString('hex')}.${ext}`;
  await fs.mkdir(dataPath('uploads'), { recursive: true });
  await fs.writeFile(uploadPath(name), bytes);
  return { name, url: `/api/uploads/${name}`, size: bytes.length };
}
