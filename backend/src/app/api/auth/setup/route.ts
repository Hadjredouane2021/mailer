import { z } from 'zod';
import { isSetupKeyRequired, isSetupKeyValid, issueToken } from '@/lib/auth';
import { HttpError, api, readBody } from '@/lib/http';
import { countUsers, createUser, publicUser } from '@/lib/users';

export const GET = api(
  async () => ({ needsSetup: (await countUsers()) === 0, requiresKey: isSetupKeyRequired() }),
  { public: true },
);

const schema = z.looseObject({ setupKey: z.string().optional() });

/**
 * Premier lancement : création du compte administrateur.
 * Si API_TOKEN est défini, sa valeur sert de clé d'installation.
 */
export const POST = api(
  async (req) => {
    const body = schema.parse(await readBody(req));
    if ((await countUsers()) > 0) throw new HttpError(409, 'Le compte administrateur existe déjà : connectez-vous.');
    if (!isSetupKeyValid(body.setupKey)) throw new HttpError(403, 'Clé d’installation incorrecte.');
    const user = await createUser({ ...body, role: 'admin' }, { firstAdmin: true });
    return { ...(await issueToken(user)), user: publicUser(user) };
  },
  { public: true },
);
