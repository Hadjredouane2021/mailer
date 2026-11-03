import { api } from '@/lib/http';
import { createTransport } from '@/lib/mailer';
import { getSettings, smtpSchema, withStoredPassword } from '@/lib/settings';

/** Vérifie la connexion + l'authentification SMTP, sans envoyer de message. */
export const POST = api(async (req) => {
  const current = await getSettings();
  const body = (await req.json().catch(() => ({}))) as { smtp?: unknown };
  const smtp = body.smtp ? withStoredPassword(smtpSchema.parse(body.smtp), current.smtp) : current.smtp;
  const transport = createTransport(smtp);
  try {
    await transport.verify();
    return { ok: true, message: `Serveur ${smtp.host}:${smtp.port} joignable, authentification réussie.` };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : String(error) };
  } finally {
    transport.close();
  }
}, { role: 'admin' });
