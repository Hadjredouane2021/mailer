import { HttpError, api, readBody, type Principal } from '@/lib/http';
import { getUser, publicUser, updateProfile } from '@/lib/users';

async function requireAccount(auth: Principal) {
  if (auth.service) throw new HttpError(400, 'Le jeton de service n’a pas de compte utilisateur.');
  const user = await getUser(auth.id);
  if (!user) throw new HttpError(404, 'Utilisateur introuvable.');
  return user;
}

/** Utilisateur connecté (le jeton de service renvoie un profil administrateur virtuel). */
export const GET = api(async (_req, _params, auth) => {
  if (auth.service) {
    return { id: auth.id, name: auth.name, email: '', role: auth.role, active: true, service: true };
  }
  return publicUser(await requireAccount(auth));
});

/** « Mon compte » : nom et adresse e-mail. */
export const PUT = api(async (req, _params, auth) => {
  const user = await requireAccount(auth);
  return publicUser(await updateProfile(user.id, await readBody(req)));
});
