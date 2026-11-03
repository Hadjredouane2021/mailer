import { promises as fs } from 'fs';
import { HttpError, api } from '@/lib/http';
import { MIME_BY_EXT, uploadPath } from '@/lib/uploads';

/** Images publiques (noms aléatoires) : utilisées par l'aperçu de l'app. */
export const GET = api<{ name: string }>(
  async (_req, { name }) => {
    const type = MIME_BY_EXT[name.split('.').pop()?.toLowerCase() ?? ''];
    if (!type) throw new HttpError(404, 'Image introuvable.');
    const bytes = await fs.readFile(uploadPath(name)).catch(() => {
      throw new HttpError(404, 'Image introuvable.');
    });
    return new Response(new Uint8Array(bytes), {
      headers: { 'Content-Type': type, 'Cache-Control': 'public, max-age=31536000, immutable' },
    });
  },
  { public: true },
);
