import { promises as fs } from 'fs';
import nodemailer, { type Transporter } from 'nodemailer';
import type { Campaign } from './campaigns';
import { renderMessage } from './render';
import type { Row } from './recipients';
import { getSettings, type SmtpSettings } from './settings';
import { dataPath } from './store';

/** MAIL_DRY_RUN=1 : rien ne part, le dernier message est écrit dans data/dry-run/last.eml. */
export const isDryRun = process.env.MAIL_DRY_RUN === '1';

/** Équivalent du $mail PHPMailer : SMTPS 465 sur smtp-pulse.com, authentification. */
export function createTransport(smtp: SmtpSettings, pool = false): Transporter {
  if (isDryRun) return nodemailer.createTransport({ streamTransport: true, buffer: true, newline: 'unix' });
  return nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    auth: { user: smtp.user, pass: smtp.password },
    pool,
    maxConnections: 1,
    connectionTimeout: 20_000,
    greetingTimeout: 20_000,
    socketTimeout: 60_000,
  });
}

export async function defaultTransport(pool = false): Promise<Transporter> {
  return createTransport((await getSettings()).smtp, pool);
}

export async function sendCampaignMail(
  transport: Transporter,
  campaign: Campaign,
  row: Row | null,
  to: string,
  subjectPrefix = '',
): Promise<{ ok: boolean; message: string }> {
  try {
    const message = renderMessage(campaign, row, { kind: 'send' });
    const info = await transport.sendMail({
      from: { name: campaign.fromName, address: campaign.fromEmail },
      to,
      replyTo: campaign.replyTo || undefined,
      subject: subjectPrefix + message.subject,
      html: message.html,
      text: message.text,
      attachments: message.attachments,
    });
    if (isDryRun) {
      await fs.mkdir(dataPath('dry-run'), { recursive: true });
      await fs.writeFile(dataPath('dry-run', 'last.eml'), info.message as Buffer);
      return { ok: true, message: 'Simulé (MAIL_DRY_RUN)' };
    }
    const rejected = (info.rejected ?? []).map(String);
    if (rejected.length > 0) return { ok: false, message: `Refusé : ${rejected.join(', ')}` };
    return { ok: true, message: 'Envoyé' };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : String(error) };
  }
}
