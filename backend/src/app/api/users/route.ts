import { api, readBody } from '@/lib/http';
import { createUser, listUsers, publicUser } from '@/lib/users';

export const GET = api(async () => listUsers(), { role: 'admin' });

export const POST = api(async (req) => publicUser(await createUser(await readBody(req))), { role: 'admin' });
