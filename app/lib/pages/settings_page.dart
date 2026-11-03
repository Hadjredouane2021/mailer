import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

/// Réglages serveur (administrateurs) : connexion MySQL, SMTP ($mail PHPMailer) et valeurs par défaut.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return PageScaffold(
      maxWidth: 1080,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            eyebrow: 'Administration',
            title: 'Paramètres',
            subtitle: 'Enregistrés côté API (backend/data/settings.json), ils priment sur .env.local.',
          ),
          Loader<AppSettings>(
            load: api.settings,
            builder: (context, settings, _) => _SettingsForm(settings: settings),
          ),
        ],
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.settings});

  final AppSettings settings;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final Api _api = context.read<Session>().api;
  late final _db = {
    for (final k in ['host', 'port', 'user', 'database'])
      k: TextEditingController(text: '${widget.settings.db[k] ?? ''}'),
    'password': TextEditingController(),
  };
  late final _smtp = {
    for (final k in ['host', 'port', 'user']) k: TextEditingController(text: '${widget.settings.smtp[k] ?? ''}'),
    'password': TextEditingController(),
  };
  late bool _secure = widget.settings.smtp['secure'] != false;
  late final _defaults = {
    for (final k in ['fromName', 'batchSize', 'pauseSeconds'])
      k: TextEditingController(text: '${widget.settings.defaults[k] ?? ''}'),
  };
  late final List<String> _senders = [...widget.settings.senders];
  late String _fromEmail = '${widget.settings.defaults['fromEmail'] ?? ''}'.toLowerCase();
  final _newSender = TextEditingController();
  String? _busy;
  final Map<String, CheckResult> _checks = {};

  @override
  void dispose() {
    for (final c in [..._db.values, ..._smtp.values, ..._defaults.values, _newSender]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _dbPayload() => {
    'host': _db['host']!.text.trim(),
    'port': int.tryParse(_db['port']!.text.trim()) ?? 3306,
    'user': _db['user']!.text.trim(),
    'password': _db['password']!.text,
    'database': _db['database']!.text.trim(),
  };

  Map<String, dynamic> _smtpPayload() => {
    'host': _smtp['host']!.text.trim(),
    'port': int.tryParse(_smtp['port']!.text.trim()) ?? 465,
    'secure': _secure,
    'user': _smtp['user']!.text.trim(),
    'password': _smtp['password']!.text,
  };

  Map<String, dynamic> _defaultsPayload() => {
    'fromName': _defaults['fromName']!.text.trim(),
    'fromEmail': _fromEmail,
    'senders': _senders,
    'batchSize': int.tryParse(_defaults['batchSize']!.text.trim()) ?? 20,
    'pauseSeconds': int.tryParse(_defaults['pauseSeconds']!.text.trim()) ?? 120,
  };

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _test(String key, Future<CheckResult> Function() check) => _run('test-$key', () async {
    final result = await check();
    if (mounted) setState(() => _checks[key] = result);
  });

  Future<void> _save(String key, Map<String, dynamic> patch) => _run('save-$key', () async {
    await _api.saveSettings(patch);
    _db['password']!.clear();
    _smtp['password']!.clear();
    if (mounted) showToast(context, 'Paramètres enregistrés.');
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeIn(
          child: _section(
            context,
            key: 'db',
            icon: Icons.storage_rounded,
            tone: Tone.iris,
            title: 'Base de données MySQL',
            subtitle: 'Même base que le projet PHP (mailing_settings.json)',
            fields: [
              _text('Hôte', _db['host']!),
              _text('Port', _db['port']!, digits: true),
              _text('Utilisateur', _db['user']!),
              _password(widget.settings.db['hasPassword'] == true, _db['password']!),
              _text('Base de données', _db['database']!),
            ],
            onTest: () => _test('db', () => _api.testDb(_dbPayload())),
            onSave: () => _save('db', {'db': _dbPayload()}),
          ),
        ),
        const SizedBox(height: 16),
        FadeIn(
          delay: const Duration(milliseconds: 60),
          child: _section(
            context,
            key: 'smtp',
            icon: Icons.outgoing_mail,
            tone: Tone.accent,
            title: 'Serveur SMTP',
            subtitle: 'Équivalent du \$mail PHPMailer (smtp-pulse.com, port 465 SSL)',
            fields: [
              _text('Hôte SMTP', _smtp['host']!),
              _text('Port', _smtp['port']!, digits: true),
              _text('Utilisateur', _smtp['user']!),
              _password(widget.settings.smtp['hasPassword'] == true, _smtp['password']!),
              Field(
                label: 'Chiffrement',
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
                  decoration: BoxDecoration(
                    color: context.palette.field,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: context.palette.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _secure ? 'SSL/TLS (SMTPS)' : 'STARTTLS / aucun',
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                      Switch(value: _secure, onChanged: (v) => setState(() => _secure = v)),
                    ],
                  ),
                ),
              ),
            ],
            onTest: () => _test('smtp', () => _api.testSmtp(_smtpPayload())),
            onSave: () => _save('smtp', {'smtp': _smtpPayload()}),
          ),
        ),
        const SizedBox(height: 16),
        FadeIn(
          delay: const Duration(milliseconds: 120),
          child: _section(
            context,
            key: 'defaults',
            icon: Icons.auto_awesome_outlined,
            tone: Tone.success,
            title: 'Valeurs par défaut',
            subtitle: 'Pré-remplies à la création d’une campagne',
            fields: [
              _text('Nom d’expéditeur', _defaults['fromName']!),
              Field(
                label: 'E-mail d’expéditeur par défaut',
                child: DropdownButtonFormField<String>(
                  key: ValueKey('default-sender-${_senders.join()}'),
                  initialValue: _senders.contains(_fromEmail) ? _fromEmail : null,
                  isExpanded: true,
                  style: context.textTheme.bodyMedium,
                  borderRadius: BorderRadius.circular(radiusMd),
                  dropdownColor: context.palette.surface,
                  hint: const Text('Choisir…'),
                  items: [
                    for (final s in _senders)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _fromEmail = v ?? _fromEmail),
                ),
              ),
              _text('E-mails par lot', _defaults['batchSize']!, digits: true),
              _text('Pause entre lots (s)', _defaults['pauseSeconds']!, digits: true),
            ],
            footer: _sendersEditor(context),
            onSave: () => _save('defaults', {'defaults': _defaultsPayload()}),
          ),
        ),
      ],
    );
  }

  void _addSender() {
    final email = _newSender.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      showToast(context, 'Adresse e-mail invalide.', error: true);
      return;
    }
    if (!_senders.contains(email)) setState(() => _senders.add(email));
    _newSender.clear();
  }

  /// Liste des adresses d'expéditeur proposées dans l'éditeur de campagne.
  Widget _sendersEditor(BuildContext context) {
    final p = context.palette;
    return Field(
      label: 'Adresses d’expéditeur autorisées',
      hint:
          'Seules ces adresses peuvent être choisies comme expéditeur d’une campagne '
          '(elles doivent être validées chez votre fournisseur SMTP).',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _senders)
                  Chip(
                    avatar: Icon(Icons.alternate_email_rounded, size: 15, color: p.accent),
                    label: Text(s == _fromEmail ? '$s · par défaut' : s),
                    // L'expéditeur par défaut ne peut pas être retiré de la liste.
                    onDeleted: _senders.length <= 1 || s == _fromEmail
                        ? null
                        : () => setState(() => _senders.remove(s)),
                    deleteButtonTooltipMessage: 'Retirer',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSender,
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _addSender(),
                    decoration: const InputDecoration(hintText: 'Ajouter une adresse…'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _addSender,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String label, TextEditingController c, {bool digits = false}) => Field(
    label: label,
    child: TextField(
      controller: c,
      keyboardType: digits ? TextInputType.number : null,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
    ),
  );

  Widget _password(bool hasPassword, TextEditingController c) => Field(
    label: 'Mot de passe',
    child: PasswordField(controller: c, hint: hasPassword ? '•••••••• (inchangé)' : 'Aucun'),
  );

  Widget _section(
    BuildContext context, {
    required String key,
    required IconData icon,
    required Tone tone,
    required String title,
    required String subtitle,
    required List<Widget> fields,
    Widget? footer,
    VoidCallback? onTest,
    required VoidCallback onSave,
  }) {
    final p = context.palette;
    final check = _checks[key];
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: Row(
              children: [
                IconBadge(icon, tone: tone, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.textTheme.titleMedium),
                      Text(subtitle, style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(minItemWidth: 220, spacing: 14, children: fields),
                if (footer != null) ...[const SizedBox(height: 16), footer],
                if (check != null) ...[
                  const SizedBox(height: 16),
                  InfoBanner(
                    tone: check.ok ? Tone.success : Tone.danger,
                    icon: check.ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    text: check.message,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: p.surfaceHigh.withValues(alpha: 0.6),
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onTest != null)
                  OutlinedButton.icon(
                    onPressed: _busy != null ? null : onTest,
                    icon: _busy == 'test-$key'
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Tester la connexion'),
                  ),
                FilledButton.icon(
                  onPressed: _busy != null ? null : onSave,
                  icon: _busy == 'save-$key'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
