# Mailler Studio

Migration du projet PHP `C:\wamp64\www\mailler` vers **Flutter (interface) + Next.js (API)**.
Même base MySQL `mail`, mêmes tables de destinataires (`email`, `sent`), même compte SMTP que le `$mail` PHPMailer.

```
mailler-studio/
├── backend/   API Next.js 16 (TypeScript) : MySQL (mysql2) + SMTP (nodemailer) + moteur d'envoi par lots
└── app/       Application Flutter (web, Windows, Android) : provider, go_router, http
```

## Démarrage rapide

```bash
cd backend
npm install
npm run build:app   # compile l'app Flutter et la copie dans public/app
npm run build
npm start           # http://localhost:4100/app/
```

Premier lancement : l'app propose de **créer le compte administrateur** (nom, e-mail, mot de passe).
La clé d'installation demandée est la valeur `API_TOKEN` de `backend/.env.local`. Ensuite, chacun se connecte
avec son e-mail et son mot de passe ; l'administrateur invite l'équipe depuis **Utilisateurs**.

### Développement

```bash
cd backend && npm run dev            # API sur http://localhost:4100
cd app && flutter run -d chrome      # interface (adresse de l'API : http://localhost:4100)
```

Version Windows (`flutter run -d windows`) : installer d'abord le composant Visual Studio
« Développement Desktop en C++ » (signalé par `flutter doctor`). Hors web, l'aperçu HTML s'ouvre dans le navigateur.

## Configuration (`backend/.env.local`)

| Variable | Rôle |
| --- | --- |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Base MySQL (reprise de `mailing_settings.json`) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASSWORD` | SMTP (repris du `$mail` de `send.php` / `sendpub.php`) |
| `MAIL_FROM_EMAIL`, `MAIL_FROM_NAME`, `DEFAULT_BATCH_SIZE`, `DEFAULT_PAUSE_SECONDS` | Valeurs par défaut des nouvelles campagnes |
| `MAIL_SENDERS` | Adresses d'expéditeur autorisées, séparées par des virgules (défaut : `newsletter@fma.org.ma,inscription@rdvdelassurance.ma`) |
| `API_TOKEN` | Clé d'installation du premier administrateur + jeton de service (accès admin) pour les scripts |
| `AUTH_SECRET` | Clé de signature des sessions (facultatif : générée dans `data/auth-secret`) |
| `MAIL_DRY_RUN=1` | Simulation : rien n'est envoyé, le dernier message est écrit dans `data/dry-run/last.eml` (la colonne `sent` est quand même mise à jour) |

Les réglages modifiés depuis l'écran **Paramètres** sont enregistrés dans `backend/data/settings.json` et priment sur `.env.local`.

## Utilisateurs et rôles

| Rôle | Droits |
| --- | --- |
| **Lecteur** | Tableau de bord, campagnes, destinataires, historique et journaux : consultation seule |
| **Éditeur** | + créer / modifier / supprimer des campagnes, envoyer des tests, lancer et piloter les envois, modifier la colonne `sent` |
| **Administrateur** | + gestion des utilisateurs (création, rôle, désactivation, réinitialisation du mot de passe) et paramètres serveur |

- Comptes stockés dans `backend/data/users.json` (mots de passe hachés avec scrypt, jamais renvoyés par l'API).
- Sessions signées valables 14 jours. Changer un mot de passe, le réinitialiser ou désactiver un compte ferme ses sessions ouvertes.
- 5 échecs de connexion en 10 min bloquent temporairement l'adresse concernée.
- Garde-fous : il reste toujours au moins un administrateur actif ; on ne peut ni supprimer, ni désactiver, ni rétrograder son propre compte.
- Les envois et les campagnes gardent le nom de l'auteur (« lancé par », « modifiée par »).

## Expéditeurs autorisés

L'e-mail d'expéditeur d'une campagne se choisit dans une liste : par défaut **newsletter@fma.org.ma** et
**inscription@rdvdelassurance.ma**. Un administrateur modifie la liste dans **Paramètres › Valeurs par défaut** ;
l'API refuse toute autre adresse.

## Interface

Thème sombre / clair / système, barre latérale flottante (bureau), rail (tablette), dock en bas d'écran (mobile).
**Ctrl K** ouvre la palette de commandes : navigation, actions, recherche de campagnes.

## Correspondance avec le projet PHP

| PHP | Mailler Studio |
| --- | --- |
| `index.php` (statut des destinataires) | **Destinataires** : recherche, filtre envoyés / en attente, pagination, bascule `sent` par ligne |
| `admin.php` (config, reset sent, éditeur) | **Paramètres** + **Réinitialiser** (Destinataires) + **éditeur de campagne** |
| `send.php`, `send_fr.php`, `send_en.php`, `sendpub.php`, `send_transfert.php`, `sendcat.php`… | Une **campagne** par script, importée automatiquement au premier lancement (`backend/data/seed/campaigns.json`) |
| Rechargement de page + pause `RDV_BATCH_PAUSE_SECONDS` | **Moteur d'envoi côté serveur** : lots, pause entre lots, pause / reprise / arrêt, journal en direct. L'envoi continue si l'app est fermée |
| `upload_image.php` | Téléversement d'images ; elles sont **jointes en CID** à l'e-mail (visibles chez tous les destinataires) |

### Personnalisation (syntaxe Mustache)

- `{{colonne}}` : n'importe quelle colonne de la table (`{{prenom}}`, `{{email}}`, `{{uuid}}`…)
- `{{fullname}}` : civilité + prénom + nom
- `Bonjour{{#fullname}} {{fullname}}{{/fullname}},` : salutation, avec le nom seulement s'il est connu
- `{{#url}}{{uuid}}{{/url}}` : valeur encodée pour une URL (lien de transfert)

Un corps sans balise `<html>` est automatiquement placé dans une mise en page e-mail de 700 px.

## Sécurité du moteur d'envoi

- Un seul envoi à la fois par table (les doublons sont refusés).
- Une adresse en échec reste à `sent=0` et n'est pas retentée en boucle dans le même envoi.
- Après 5 échecs consécutifs (SMTP en panne, quota…), l'envoi s'arrête avec le message d'erreur.
- Si le serveur API redémarre pendant un envoi, celui-ci passe en « Échec » ; on le relance depuis la console (seuls les `sent=0` repartent).

> Le projet PHP reste intact. Ne lancez pas un envoi PHP et un envoi Mailler Studio en même temps sur la **même table**.

## Données locales (`backend/data/`, non versionné)

`campaigns.json`, `settings.json`, `jobs.json` (historique), `logs/<envoi>.jsonl` (journal détaillé), `daily.json` (statistiques), `uploads/` (images).
