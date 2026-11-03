import { HttpError, api } from '@/lib/http';
import { saveUpload } from '@/lib/uploads';

/** Téléversement d'une image (champ multipart « file »), comme upload_image.php. */
export const POST = api(async (req) => {
  const form = await req.formData().catch(() => null);
  const file = form?.get('file');
  if (!(file instanceof File)) throw new HttpError(400, 'Aucun fichier reçu (champ « file »).');
  return saveUpload(file);
}, { role: 'editor' });
