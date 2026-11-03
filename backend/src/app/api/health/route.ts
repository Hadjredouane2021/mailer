import { isSetupKeyRequired } from '@/lib/auth';
import { query } from '@/lib/db';
import { api } from '@/lib/http';
import { isDryRun } from '@/lib/mailer';
import { countUsers } from '@/lib/users';

export const GET = api(
  async () => {
    let database: 'ok' | 'error' = 'ok';
    try {
      await query('SELECT 1');
    } catch {
      database = 'error';
    }
    return {
      ok: true,
      name: 'Mailler Studio API',
      version: '2.0.0',
      database,
      dryRun: isDryRun,
      // Premier lancement : aucun compte, l'app propose de créer l'administrateur.
      needsSetup: (await countUsers()) === 0,
      setupRequiresKey: isSetupKeyRequired(),
    };
  },
  { public: true },
);
