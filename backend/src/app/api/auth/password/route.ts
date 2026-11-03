import { z } from 'zod';
import { issueToken } from '@/lib/auth';
import { HttpError, api, readBody } from '@/lib/http';
import { changePassword, publicUser } from '@/lib/users';

const schema = z.object({
  currentPassword: z.string().min(1, 'obligatoire'),
  newPassword: z.string(),
});

/** Change son mot de passe : les autres sessions sont fermées, un nouveau jeton est renvoyé. */
export const PUT = api(async (req, _params, auth) => {
  if (auth.service) throw new HttpError(400, 'Le jeton de service n’a pas de mot de passe.');
  const { currentPassword, newPassword } = schema.parse(await readBody(req));
  const user = await changePassword(auth.id, currentPassword, newPassword);
  return { ...(await issueToken(user)), user: publicUser(user) };
});
