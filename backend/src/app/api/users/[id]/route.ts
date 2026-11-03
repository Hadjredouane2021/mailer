import { api, readBody } from '@/lib/http';
import { deleteUser, publicUser, updateUser } from '@/lib/users';

export const PUT = api<{ id: string }>(
  async (req, { id }, auth) => publicUser(await updateUser(id, await readBody(req), auth.id)),
  { role: 'admin' },
);

export const DELETE = api<{ id: string }>(
  async (_req, { id }, auth) => {
    await deleteUser(id, auth.id);
    return { ok: true };
  },
  { role: 'admin' },
);
