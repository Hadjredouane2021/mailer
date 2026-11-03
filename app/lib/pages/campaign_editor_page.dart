import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/html_code.dart';
import '../ui/html_preview.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

const _starterBody = '''<p>Bonjour{{#fullname}} {{fullname}}{{/fullname}},</p>
<p>Nous avons le plaisir de vous informer que…</p>
<p style="margin:28px 0;">
  <a href="https://www.rdvdelassurance.ma" target="_blank" style="background:#0b2f52;color:#ffffff;padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:bold;">En savoir plus</a>
</p>
<p>Cordialement,</p>''';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _fullDocument = RegExp(r'<html[\s>]', caseSensitive: false);

enum _PreviewMode { desktop, mobile, text }

class CampaignEditorPage extends StatefulWidget {
  const CampaignEditorPage({super.key, this.campaignId});

  final String? campaignId;

  @override
  State<CampaignEditorPage> createState() => _CampaignEditorPageState();
}

class _CampaignEditorPageState extends State<CampaignEditorPage> {
  late final Api _api = context.read<Session>().api;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _subject = TextEditingController();
  final _fromName = TextEditingController();
  final _fromEmail = TextEditingController();
  final _replyTo = TextEditingController();
  final _altBody = TextEditingController();
  final _batchSize = TextEditingController();
  final _pause = TextEditingController();
  final _body = HtmlCodeController();

  Campaign? _campaign;
  List<TableInfo> _tables = const [];

  /// Expéditeurs autorisés (Paramètres › Valeurs par défaut).
  List<String> _senders = const [];
  String _table = '';
  CampaignStatus _status = CampaignStatus.draft;

  bool _loading = true;
  Object? _loadError;
  bool _dirty = false;
  bool _saving = false;

  Preview? _preview;
  String? _previewError;
  bool _previewLoading = false;
  Timer? _debounce;
  _PreviewMode _mode = _PreviewMode.desktop;

  bool get _isNew => _campaign == null;

  bool get _canEdit => context.read<Session>().canEdit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _name,
      _description,
      _subject,
      _fromName,
      _fromEmail,
      _replyTo,
      _altBody,
      _batchSize,
      _pause,
      _body,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([_api.tables(), _api.settings()]);
      final tables = results[0] as List<TableInfo>;
      final settings = results[1] as AppSettings;
      _senders = settings.senders;
      if (widget.campaignId != null) {
        _fill(await _api.campaign(widget.campaignId!), tables);
      } else {
        final defaults = settings.defaults;
        final table = tables.any((t) => t.name == 'test') ? 'test' : (tables.isEmpty ? '' : tables.first.name);
        _name.text = 'Nouvelle campagne';
        _fromName.text = '${defaults['fromName'] ?? ''}';
        _fromEmail.text = '${defaults['fromEmail'] ?? ''}';
        _batchSize.text = '${defaults['batchSize'] ?? 20}';
        _pause.text = '${defaults['pauseSeconds'] ?? 120}';
        _body.text = _starterBody;
        _table = table;
      }
      _tables = tables;
      for (final c in [_name, _description, _fromName, _fromEmail, _replyTo, _batchSize, _pause]) {
        c.addListener(_touch);
      }
      for (final c in [_subject, _body, _altBody]) {
        c.addListener(_touchContent);
      }
      setState(() {
        _loading = false;
        _dirty = widget.campaignId == null;
      });
      _refreshPreview();
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _fill(Campaign c, List<TableInfo> tables) {
    _campaign = c;
    _name.text = c.name;
    _description.text = c.description;
    _subject.text = c.subject;
    _fromName.text = c.fromName;
    _fromEmail.text = c.fromEmail;
    _replyTo.text = c.replyTo;
    _altBody.text = c.altBody;
    _batchSize.text = '${c.batchSize}';
    _pause.text = '${c.pauseSeconds}';
    _body.text = c.bodyHtml;
    _table = c.table;
    _status = c.status;
  }

  void _touch() {
    if (!_dirty && !_loading) setState(() => _dirty = true);
  }

  void _touchContent() {
    _touch();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final preview = await _api.preview(
        subject: _subject.text,
        bodyHtml: _body.text,
        altBody: _altBody.text,
        table: _table,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _previewError = '$e');
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  TableInfo? get _tableInfo => _tables.where((t) => t.name == _table).firstOrNull;

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Donnez un nom à la campagne.';
    if (_table.isEmpty) return 'Choisissez une table de destinataires.';
    if (_subject.text.trim().isEmpty) return 'L’objet est obligatoire.';
    if (_body.text.trim().isEmpty) return 'Le contenu HTML est vide.';
    if (_fromName.text.trim().isEmpty) return 'Le nom d’expéditeur est obligatoire.';
    if (!_emailPattern.hasMatch(_fromEmail.text.trim())) return 'Adresse d’expéditeur invalide.';
    if (_senders.isNotEmpty && !_senders.contains(_fromEmail.text.trim().toLowerCase())) {
      return 'Choisissez un expéditeur autorisé : ${_senders.join(' ou ')}.';
    }
    if (_replyTo.text.trim().isNotEmpty && !_emailPattern.hasMatch(_replyTo.text.trim())) {
      return 'Adresse « Répondre à » invalide.';
    }
    final batch = int.tryParse(_batchSize.text.trim());
    if (batch == null || batch < 1 || batch > 500) return 'Taille de lot : entre 1 et 500.';
    final pause = int.tryParse(_pause.text.trim());
    if (pause == null || pause < 0 || pause > 3600) return 'Pause entre lots : entre 0 et 3600 secondes.';
    return null;
  }

  Map<String, dynamic> _payload() => {
    'name': _name.text.trim(),
    'description': _description.text.trim(),
    'status': _status.name,
    'table': _table,
    'fromName': _fromName.text.trim(),
    'fromEmail': _fromEmail.text.trim(),
    'replyTo': _replyTo.text.trim(),
    'subject': _subject.text.trim(),
    'bodyHtml': _body.text,
    'altBody': _altBody.text,
    'batchSize': int.parse(_batchSize.text.trim()),
    'pauseSeconds': int.parse(_pause.text.trim()),
  };

  /// Enregistre ; renvoie la campagne à jour (null si échec).
  Future<Campaign?> _save({bool quiet = false}) async {
    if (!_canEdit) return null;
    final problem = _validate();
    if (problem != null) {
      showToast(context, problem, error: true);
      return null;
    }
    setState(() => _saving = true);
    try {
      final saved = _isNew
          ? await _api.createCampaign(_payload())
          : await _api.updateCampaign(_campaign!.id, _payload());
      if (!mounted) return saved;
      final wasNew = _isNew;
      setState(() {
        _campaign = saved;
        _dirty = false;
      });
      if (!quiet) showToast(context, 'Campagne enregistrée.');
      if (wasNew) context.go('/campaigns/${saved.id}');
      return saved;
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Campaign?> _ensureSaved() async => (_dirty || _isNew) ? _save(quiet: true) : _campaign;

  Future<void> _sendTest() async {
    final session = context.read<Session>();
    final campaign = await _ensureSaved();
    if (campaign == null || !mounted) return;
    final controller = TextEditingController(text: session.lastTestEmail);
    final to = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Envoyer un e-mail de test',
        subtitle:
            'Rendu avec un destinataire réel de « ${campaign.table} ». '
            'L’objet est préfixé par [TEST] et la colonne sent n’est pas modifiée.',
        icon: Icons.science_outlined,
        tone: Tone.iris,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          GradientButton(
            label: 'Envoyer le test',
            icon: Icons.send_rounded,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
        child: Field(
          label: 'Adresse de réception',
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 19),
              hintText: 'vous@exemple.ma',
            ),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
      ),
    );
    controller.dispose();
    if (to == null || to.isEmpty || !mounted) return;
    if (!_emailPattern.hasMatch(to)) {
      showToast(context, 'Adresse de test invalide.', error: true);
      return;
    }
    await session.rememberTestEmail(to);
    try {
      final result = await _api.sendTest(campaign.id, to);
      if (mounted) showToast(context, result.ok ? 'Test envoyé à $to.' : result.message, error: !result.ok);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _launch() async {
    final campaign = await _ensureSaved();
    if (campaign == null || !mounted) return;
    final tables = await _api.tables().catchError((_) => _tables);
    if (!mounted) return;
    final counts = tables.where((t) => t.name == campaign.table).firstOrNull;
    if (counts != null && counts.pending == 0) {
      showToast(
        context,
        'Aucun destinataire en attente dans « ${campaign.table} ». Réinitialisez la table d’abord.',
        error: true,
      );
      return;
    }
    await launchCampaign(context, campaign, counts: counts);
  }

  // ── Barre d'outils de l'éditeur HTML

  Future<String?> _ask(String title, String label, {String initial = 'https://'}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        maxWidth: 440,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Insérer')),
        ],
        child: Field(
          label: label,
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
      ),
    );
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _insertLink() async {
    final url = await _ask('Insérer un lien', 'URL');
    if (url == null) return;
    final label = _body.selectedText.isEmpty ? url : '';
    _body.wrap('<a href="$url" target="_blank" style="color:#1d4f80;">$label', '</a>');
  }

  Future<void> _insertButton() async {
    final url = await _ask('Bouton d’action', 'URL du bouton');
    if (url == null) return;
    final label = await _ask('Bouton d’action', 'Texte du bouton', initial: 'En savoir plus');
    if (label == null) return;
    _body.insert(
      '\n<p style="margin:28px 0;">\n  <a href="$url" target="_blank" style="background:#0b2f52;color:#ffffff;'
      'padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:bold;">$label</a>\n</p>\n',
    );
  }

  Future<void> _insertImageUrl() async {
    final url = await _ask('Image depuis une URL', 'URL de l’image');
    if (url == null) return;
    _body.insert('<img src="$url" alt="" style="max-width:100%;height:auto;border:0;">');
  }

  Future<void> _uploadImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return;
    showToast(context, 'Téléversement de ${file.name}…');
    try {
      final url = await _api.uploadImage(await file.readAsBytes(), file.name);
      _body.insert('<img src="$url" alt="" style="max-width:100%;height:auto;border:0;">');
      if (mounted) showToast(context, 'Image ajoutée (elle sera jointe à l’e-mail).');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  void _insertColor(Color color) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    _body.wrap('<span style="color:$hex;">', '</span>');
  }

  // ── Construction

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return PageScaffold(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          tone: Tone.danger,
          title: 'Impossible d’ouvrir la campagne',
          message: '$_loadError',
          action: OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
        ),
      );
    }
    if (_loading) return const PageScaffold(child: PageSkeleton());

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _save(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => _save(),
      },
      child: Focus(
        autofocus: true,
        child: PageScaffold(
          maxWidth: 1600,
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1080;
              final canEdit = context.watch<Session>().canEdit;
              Widget guard(Widget child) => canEdit ? child : AbsorbPointer(child: child);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, canEdit),
                  if (!canEdit) const ReadOnlyBanner(),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: Column(
                            children: [
                              guard(_settingsCard(context)),
                              const SizedBox(height: 16),
                              guard(_contentCard(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 9, child: _previewCard(context, height: 1180)),
                      ],
                    )
                  else ...[
                    guard(_settingsCard(context)),
                    const SizedBox(height: 16),
                    guard(_contentCard(context)),
                    const SizedBox(height: 16),
                    _previewCard(context, height: 720),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool canEdit) {
    final p = context.palette;
    final by = _campaign?.updatedBy;
    final live = _campaign?.activeJobId;
    return PageHeader(
      eyebrow: _isNew ? 'Nouvelle campagne' : 'Campagne',
      title: _name.text.trim().isEmpty ? 'Sans titre' : _name.text.trim(),
      trailingTitle: _dirty && canEdit ? const StatusPill('Non enregistrée', tone: Tone.warning) : null,
      subtitle: _dirty && canEdit
          ? 'Modifications non enregistrées · Ctrl+S pour enregistrer'
          : 'Enregistrée ${fmtRelative(_campaign?.updatedAt)}${by == null ? '' : ' par $by'}',
      leading: IconButton.outlined(
        tooltip: 'Retour aux campagnes',
        style: IconButton.styleFrom(side: BorderSide(color: p.line)),
        onPressed: () => context.go('/campaigns'),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
      actions: [
        if (canEdit) ...[
          OutlinedButton.icon(
            onPressed: _saving ? null : _sendTest,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Envoyer un test'),
          ),
          FilledButton.icon(
            onPressed: _saving || !_dirty ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_dirty ? Icons.save_outlined : Icons.check_rounded, size: 18),
            label: Text(_dirty ? 'Enregistrer' : 'Enregistré'),
          ),
        ],
        if (live != null)
          FilledButton.icon(
            onPressed: () => context.go('/jobs/$live'),
            icon: const Icon(Icons.monitor_heart_outlined, size: 18),
            label: const Text('Suivre l’envoi'),
          )
        else if (canEdit)
          GradientButton(
            label: 'Lancer l’envoi',
            icon: Icons.rocket_launch_outlined,
            onPressed: _saving ? null : _launch,
          ),
      ],
    );
  }

  Widget _settingsCard(BuildContext context) {
    final info = _tableInfo;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            'Paramètres d’envoi',
            subtitle: 'Table cible, expéditeur et cadence (anti-throttling)',
            icon: Icons.settings_outlined,
          ),
          ResponsiveGrid(
            minItemWidth: 230,
            spacing: 14,
            children: [
              Field(
                label: 'Nom de la campagne',
                child: TextField(controller: _name, onChanged: (_) => setState(() {})),
              ),
              Field(
                label: 'Statut',
                child: DropdownButtonFormField<CampaignStatus>(
                  style: context.textTheme.bodyLarge,
                  initialValue: _status,
                  items: [for (final s in CampaignStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() {
                    _status = v ?? _status;
                    _dirty = true;
                  }),
                ),
              ),
              Field(
                label: 'Table de destinataires',
                child: DropdownButtonFormField<String>(
                  style: context.textTheme.bodyLarge,
                  initialValue: _tables.any((t) => t.name == _table) ? _table : null,
                  isExpanded: true,
                  hint: Text(_table.isEmpty ? 'Choisir…' : '$_table (introuvable)'),
                  items: [
                    for (final t in _tables)
                      DropdownMenuItem(
                        value: t.name,
                        child: Text('${t.name} · ${fmtInt(t.pending)} en attente', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _table = v ?? _table;
                      _dirty = true;
                    });
                    _refreshPreview();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Expéditeur sur sa propre ligne : nom et adresse sont souvent longs
          ResponsiveGrid(
            minItemWidth: 300,
            spacing: 14,
            children: [
              Field(
                label: 'Nom d’expéditeur',
                child: TextField(controller: _fromName),
              ),
              _senderField(context),
            ],
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            minItemWidth: 230,
            spacing: 14,
            children: [
              Field(
                label: 'Répondre à (optionnel)',
                child: TextField(controller: _replyTo, keyboardType: TextInputType.emailAddress),
              ),
              Field(
                label: 'E-mails par lot',
                child: TextField(
                  controller: _batchSize,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(suffixText: 'e-mails'),
                ),
              ),
              Field(
                label: 'Pause entre lots',
                child: TextField(
                  controller: _pause,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(suffixText: 'secondes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Field(
            label: 'Description interne',
            child: TextField(
              controller: _description,
              decoration: const InputDecoration(hintText: 'Visible uniquement dans Mailler Studio'),
            ),
          ),
          if (info != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Meter(value: info.progress, tone: info.pending == 0 ? Tone.success : Tone.accent, height: 6),
                ),
                const SizedBox(width: 14),
                Text(
                  '${fmtInt(info.sent)} / ${fmtInt(info.total)} envoyés · ${fmtInt(info.pending)} en attente',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Expéditeur : choix parmi les adresses autorisées.
  Widget _senderField(BuildContext context) {
    final p = context.palette;
    final current = _fromEmail.text.trim().toLowerCase();
    final allowed = _senders.contains(current);
    final options = [..._senders, if (current.isNotEmpty && !allowed) current];
    return Field(
      label: 'E-mail d’expéditeur',
      hint: current.isEmpty || allowed ? null : 'Adresse hors liste : choisissez une adresse autorisée.',
      child: DropdownButtonFormField<String>(
        key: ValueKey('sender-${options.join()}'),
        initialValue: current.isEmpty ? null : current,
        isExpanded: true,
        style: context.textTheme.bodyLarge,
        borderRadius: BorderRadius.circular(radiusMd),
        dropdownColor: p.surface,
        hint: const Text('Choisir…'),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email_rounded, size: 18)),
        items: [
          for (final s in options)
            DropdownMenuItem(
              value: s,
              child: Text(
                _senders.contains(s) ? s : '$s · non autorisée',
                overflow: TextOverflow.ellipsis,
                style: _senders.contains(s) ? null : TextStyle(color: p.danger),
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _fromEmail.text = v);
        },
      ),
    );
  }

  Widget _contentCard(BuildContext context) {
    final p = context.palette;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Contenu',
            subtitle: 'HTML de l’e-mail · variables {{colonne}} remplacées pour chaque destinataire',
            icon: Icons.code_rounded,
            trailing: _variablesMenu(context),
          ),
          Field(
            label: 'Objet',
            child: TextField(
              controller: _subject,
              decoration: const InputDecoration(hintText: 'Ex. : 21st Annual Gulf Insurance Forum 2026'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 1, bottom: 7),
            child: Text(
              'Corps HTML',
              style: context.textTheme.labelMedium?.copyWith(
                color: p.text.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: p.code,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _toolbar(context),
                Divider(height: 1, color: p.line),
                SizedBox(
                  height: 560,
                  child: TextField(
                    controller: _body,
                    expands: true,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: monoStyle(size: 13, color: p.text),
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                Divider(height: 1, color: p.line),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Text('${fmtInt(_body.text.length)} caractères', style: monoStyle(size: 11.5, color: p.faint)),
                      const Spacer(),
                      Text(
                        _fullDocument.hasMatch(_body.text)
                            ? 'Document HTML complet'
                            : 'Fragment · mise en page 700 px automatique',
                        style: monoStyle(size: 11.5, color: p.faint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Texte alternatif (AltBody)',
            hint: 'Version texte pour les messageries sans HTML. Vide = générée automatiquement.',
            child: TextField(controller: _altBody, minLines: 2, maxLines: 5),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final p = context.palette;
    Widget tool(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      onPressed: onTap,
      icon: Icon(icon),
    );
    Widget sep() => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6), color: p.line);
    const colors = [
      Palette.brandBlue,
      Palette.brandTurquoise,
      Palette.brandWine,
      Color(0xFF0B2F52),
      Color(0xFF174E86),
      Color(0xFF000000),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          tool(Icons.format_bold_rounded, 'Gras', () => _body.wrap('<strong>', '</strong>')),
          tool(Icons.format_italic_rounded, 'Italique', () => _body.wrap('<em>', '</em>')),
          tool(Icons.format_underlined_rounded, 'Souligné', () => _body.wrap('<u>', '</u>')),
          PopupMenuButton<Color>(
            tooltip: 'Couleur du texte',
            icon: const Icon(Icons.format_color_text_rounded, size: 19),
            onSelected: _insertColor,
            itemBuilder: (context) => [
              for (final c in colors)
                PopupMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
                        style: monoStyle(size: 12.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          sep(),
          tool(Icons.title_rounded, 'Titre', () => _body.wrap('<h2 style="margin:0 0 12px;">', '</h2>')),
          tool(Icons.notes_rounded, 'Paragraphe', () => _body.wrap('<p>', '</p>')),
          tool(Icons.keyboard_return_rounded, 'Saut de ligne', () => _body.insert('<br>\n')),
          tool(Icons.format_list_bulleted_rounded, 'Liste', () => _body.wrap('<ul>\n  <li>', '</li>\n</ul>')),
          tool(
            Icons.horizontal_rule_rounded,
            'Séparateur',
            () => _body.insert('\n<hr style="border:0;border-top:1px solid #e2e8f0;margin:24px 0;">\n'),
          ),
          sep(),
          tool(Icons.link_rounded, 'Lien', _insertLink),
          tool(Icons.smart_button_rounded, 'Bouton d’action', _insertButton),
          tool(Icons.add_photo_alternate_rounded, 'Téléverser une image', _uploadImage),
          tool(Icons.image_search_rounded, 'Image depuis une URL', _insertImageUrl),
          sep(),
          tool(
            Icons.format_align_center_rounded,
            'Centrer',
            () => _body.wrap('<div style="text-align:center;">', '</div>'),
          ),
        ],
      ),
    );
  }

  Widget _variablesMenu(BuildContext context) {
    final columns = (_tableInfo?.columns ?? const <String>[]).where((c) => c != 'sent').toList();
    final snippets = <(String, String)>[
      ('{{fullname}}', 'Civilité + prénom + nom'),
      ('Bonjour{{#fullname}} {{fullname}}{{/fullname}},', 'Salutation (nom si disponible)'),
      if (columns.contains('uuid')) ('{{#url}}{{uuid}}{{/url}}', 'uuid encodé pour une URL'),
      for (final c in columns) ('{{$c}}', 'Colonne $c'),
    ];
    return MenuAnchor(
      menuChildren: [
        for (final (snippet, label) in snippets)
          MenuItemButton(
            onPressed: () => _body.insert(snippet),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snippet,
                    style: monoStyle(size: 12.5, color: context.palette.accent, weight: FontWeight.w700),
                  ),
                  Text(label, style: context.textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.data_object_rounded, size: 18),
        label: const Text('Variables'),
      ),
    );
  }

  Widget _previewCard(BuildContext context, {required double height}) {
    final p = context.palette;
    final preview = _preview;
    final sampleEmail = '${preview?.sample?['email'] ?? 'destinataire@exemple.ma'}';
    final initials = _fromName.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    Widget body;
    if (preview == null && _previewError == null) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Skeleton(height: double.infinity, radius: radiusMd),
      );
    } else if (_previewError != null && preview == null) {
      body = EmptyState(
        icon: Icons.error_outline_rounded,
        tone: Tone.danger,
        title: 'Aperçu indisponible',
        message: _previewError,
      );
    } else if (_mode == _PreviewMode.text) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: SelectableText(preview!.text, style: monoStyle(size: 13, color: p.text)),
      );
    } else {
      final frame = HtmlPreview(
        html: preview!.html,
        externalUrl: _campaign == null ? null : _api.previewUrl(_campaign!.id),
      );
      body = _mode == _PreviewMode.mobile
          ? Center(
              child: Container(
                width: 380,
                margin: const EdgeInsets.symmetric(vertical: 22),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A),
                  borderRadius: BorderRadius.circular(46),
                  border: Border.all(color: p.lineStrong, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 18)),
                  ],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(37), child: frame),
              ),
            )
          : frame;
    }

    return SizedBox(
      height: height,
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18, color: p.muted),
                  const SizedBox(width: 10),
                  Text('Aperçu', style: context.textTheme.titleMedium),
                  const SizedBox(width: 10),
                  AnimatedOpacity(
                    opacity: _previewLoading ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  const Spacer(),
                  PillTabs<_PreviewMode>(
                    value: _mode,
                    items: const [
                      PillTab(_PreviewMode.desktop, icon: Icons.desktop_windows_outlined, tooltip: 'Bureau'),
                      PillTab(_PreviewMode.mobile, icon: Icons.smartphone_outlined, tooltip: 'Mobile'),
                      PillTab(_PreviewMode.text, icon: Icons.notes_rounded, tooltip: 'Version texte'),
                    ],
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  if (_campaign != null)
                    IconButton(
                      tooltip: 'Ouvrir le rendu enregistré dans le navigateur',
                      onPressed: () => launchUrl(Uri.parse(_api.previewUrl(_campaign!.id))),
                      icon: const Icon(Icons.open_in_new_rounded, size: 19),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  UserAvatar(name: _fromName.text, initials: initials.isEmpty ? '@' : initials, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _fromName.text,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: '  <${_fromEmail.text}>',
                                style: TextStyle(color: p.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview?.subject.isNotEmpty == true ? preview!.subject : '(sans objet)',
                          style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'À : $sampleEmail',
                          style: context.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_previewError != null && preview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(_previewError!, style: TextStyle(color: p.danger, fontSize: 12.5)),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(radiusLg)),
                child: ColoredBox(
                  color: switch (_mode) {
                    _PreviewMode.desktop => Colors.white,
                    _PreviewMode.mobile => p.surfaceHigh,
                    _PreviewMode.text => p.code,
                  },
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
