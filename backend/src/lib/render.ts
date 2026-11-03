import Mustache from 'mustache';
import { HttpError } from './errors';
import type { Row } from './recipients';
import { uploadPath } from './uploads';

export interface MessageTemplate {
  subject: string;
  bodyHtml: string;
  altBody: string;
}

export interface RenderedMessage {
  subject: string;
  html: string;
  text: string;
  attachments: Array<{ filename: string; path: string; cid: string }>;
}

/**
 * Variables disponibles dans le template (syntaxe Mustache) :
 *   {{colonne}}                     n'importe quelle colonne de la table (échappée HTML)
 *   {{fullname}}                    civ/civilite + prenom + nom
 *   {{#fullname}} …{{/fullname}}    bloc affiché seulement si la valeur existe
 *   {{#url}}{{uuid}}{{/url}}        encode le contenu pour une URL
 */
export function buildView(row: Row | null): Record<string, unknown> {
  const values: Record<string, string> = {};
  for (const [key, value] of Object.entries(row ?? {})) {
    values[key] = value === null ? '' : String(value).trim();
  }
  const fullname = [values.civ ?? values.civilite, values.prenom, values.nom]
    .filter((part) => part && part !== '')
    .join(' ');
  return {
    ...values,
    fullname,
    url: () => (text: string, render: (s: string) => string) => encodeURIComponent(render(text).trim()),
  };
}

function renderTemplate(template: string, view: Record<string, unknown>, escapeHtml: boolean): string {
  try {
    return Mustache.render(template, view, {}, escapeHtml ? undefined : { escape: (value: unknown) => String(value) });
  } catch (error) {
    throw new HttpError(400, `Template invalide : ${(error as Error).message}`);
  }
}

/** Corps sans <html> : on l'enveloppe dans une mise en page e-mail sobre (700 px). */
export function wrapDocument(body: string, title: string): string {
  if (/<html[\s>]/i.test(body)) return body;
  const safeTitle = title.replace(/[<>&"]/g, (c) => `&#${c.charCodeAt(0)};`);
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${safeTitle}</title>
</head>
<body style="margin:0; padding:0; background-color:#ffffff;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff; margin:0; padding:0;">
    <tr>
      <td align="center" style="padding:20px 12px;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:700px; width:100%; margin:0 auto;">
          <tr>
            <td align="left" style="font-family:Arial, Helvetica, sans-serif; font-size:15px; line-height:1.6; color:#000000;">
${body}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

const UPLOAD_SRC = /(src=["'])(?:https?:\/\/[^"'/]+)?\/api\/uploads\/([A-Za-z0-9_.-]+)(["'])/gi;

/** Images téléversées : jointes en CID pour qu'elles s'affichent chez tous les destinataires. */
function embedUploads(html: string): { html: string; attachments: RenderedMessage['attachments'] } {
  const attachments = new Map<string, RenderedMessage['attachments'][number]>();
  const out = html.replace(UPLOAD_SRC, (_match, open: string, name: string, close: string) => {
    const cid = `up_${name.replace(/\.[^.]+$/, '')}@mailler`;
    if (!attachments.has(cid)) attachments.set(cid, { filename: name, path: uploadPath(name), cid });
    return `${open}cid:${cid}${close}`;
  });
  return { html: out, attachments: [...attachments.values()] };
}

/** Pour l'aperçu dans l'app : URLs absolues vers l'API. */
function absolutizeUploads(html: string, origin: string): string {
  return html.replace(UPLOAD_SRC, (_m, open: string, name: string, close: string) => `${open}${origin}/api/uploads/${name}${close}`);
}

export function htmlToText(html: string): string {
  return html
    .replace(/<(style|script|head)[^>]*>[\s\S]*?<\/\1>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|tr|h[1-6]|li)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#0?39;|&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*\n\s*\n+/g, '\n\n')
    .trim();
}

export function renderMessage(
  template: MessageTemplate,
  row: Row | null,
  mode: { kind: 'send' } | { kind: 'preview'; origin: string },
): RenderedMessage {
  const view = buildView(row);
  const subject = renderTemplate(template.subject, view, false).trim();
  const body = renderTemplate(template.bodyHtml, view, true);
  const document = wrapDocument(body, subject);
  const text = template.altBody.trim() !== '' ? renderTemplate(template.altBody, view, false) : htmlToText(body);

  if (mode.kind === 'preview') {
    return { subject, html: absolutizeUploads(document, mode.origin), text, attachments: [] };
  }
  const embedded = embedUploads(document);
  return { subject, html: embedded.html, text, attachments: embedded.attachments };
}
