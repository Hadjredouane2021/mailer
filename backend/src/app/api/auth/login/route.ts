import { z } from 'zod';
import { assertLoginAllowed, clearLoginFailures, clientKey, issueToken, recordLoginFailure } from '@/lib/auth';
import { HttpError, api, readBody } from '@/lib/http';
import { checkCredentials, publicUser } from '@/lib/users';

const schema = z.object({
  email: z.string().trim().min(1, 'obligatoire'),
  password: z.string().min(1, 'obligatoire'),
});

/** Connexion e-mail + mot de passe : renvoie un jeton de session signé (14 jours). */
export const POST = api(
  async (req) => {
    const { email, password } = schema.parse(await readBody(req));
    const key = clientKey(req, email);
    assertLoginAllowed(key);

    const check = await checkCredentials(email, password);
    if (!check.ok) {
      if (check.disabled) throw new HttpError(403, 'Ce compte est désactivé. Contactez un administrateur.');
      recordLoginFailure(key);
      throw new HttpError(401, 'E-mail ou mot de passe incorrect.');
    }
    clearLoginFailures(key);
    return { ...(await issueToken(check.user)), user: publicUser(check.user) };
  },
  { public: true },
);
