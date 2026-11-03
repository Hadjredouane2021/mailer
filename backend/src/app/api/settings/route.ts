import { api, readBody } from '@/lib/http';
import { getSettings, publicSettings, settingsPatchSchema, updateSettings } from '@/lib/settings';

export const GET = api(async () => publicSettings(await getSettings()));

export const PUT = api(async (req) => {
  const patch = settingsPatchSchema.parse(await readBody(req));
  return publicSettings(await updateSettings(patch));
}, { role: 'admin' });
