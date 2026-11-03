import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Gestion des comptes (administrateurs) : création, rôles, activation, mots de passe.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key, this.openCreate = false});

  final bool openCreate;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final Api _api = context.read<Session>().api;
  List<AppUser>? _users;
  Object? _error;
  String _query = '';
  Role? _role;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openCreate) WidgetsBinding.instance.addPostFrameCallback((_) => _edit());
  }

  Future<void> _load() async {
    try {
      final users = await _api.users();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([AppUser? user]) async {
    final me = context.read<Session>().user;
    final result = await showDialog<_DialogResult>(
      context: context,
      builder: (_) => _UserDialog(api: _api, user: user, isSelf: user != null && user.id == me?.id),
    );
    if (result == null || !mounted) return;
    await _load();
    if (!mounted) return;
    if (result.password != null) {
      await _showCredentials(result.user, result.password!, created: user == null);
    } else {
      showToast(context, user == null ? 'Compte créé.' : 'Modifications enregistrées.');
    }
    // Son propre profil a changé : mettre à jour la session.
    if (result.user.id == me?.id && mounted) context.read<Session>().updateUser(result.user);
  }

  Future<void> _showCredentials(AppUser user, String password, {required bool created}) async {
    final url = context.read<Session>().serverUrl;
    final appUrl = '$url/app/';
    final text = 'Mailler Studio\nAdresse : $appUrl\nE-mail : ${user.email}\nMot de passe : $password';
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: created ? 'Compte créé' : 'Mot de passe réinitialisé',
        subtitle:
            'Transmettez ces identifiants à ${user.name} par un canal sûr. '
            'Le mot de passe ne sera plus affiché.',
        icon: Icons.key_rounded,
        tone: Tone.success,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          GradientButton(
            label: 'Copier les identifiants',
            icon: Icons.copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
              showToast(this.context, 'Identifiants copiés dans le presse-papiers.');
            },
          ),
        ],
        child: DetailRows([
          ('Adresse', appUrl),
          ('E-mail', user.email),
          ('Mot de passe', password),
          ('Rôle', user.role.label),
        ]),
      ),
    );
  }

  Future<void> _resetPassword(AppUser user) async {
    final ok = await confirmAction(
      context,
      title: 'Réinitialiser le mot de passe ?',
      message: 'Un nouveau mot de passe sera généré pour ${user.name}. Ses sessions ouvertes seront fermées.',
      confirmLabel: 'Générer',
      icon: Icons.lock_reset_rounded,
    );
    if (!ok || !mounted) return;
    final password = generatePassword();
    try {
      final updated = await _api.updateUser(user.id, {'password': password});
      await _load();
      if (mounted) await _showCredentials(updated, password, created: false);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _toggleActive(AppUser user) async {
    if (user.active) {
      final ok = await confirmAction(
        context,
        title: 'Désactiver ${user.name} ?',
        message:
            'Le compte ne pourra plus se connecter et ses sessions ouvertes seront fermées. '
            'Vous pourrez le réactiver à tout moment.',
        confirmLabel: 'Désactiver',
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!ok) return;
    }
    try {
      await _api.updateUser(user.id, {'active': !user.active});
      await _load();
      if (mounted) showToast(context, user.active ? '${user.name} est désactivé.' : '${user.name} est réactivé.');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(AppUser user) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ${user.name} ?',
      message:
          'Le compte ${user.email} sera supprimé définitivement. '
          'L’historique des envois garde le nom de la personne.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    try {
      await _api.deleteUser(user.id);
      await _load();
      if (mounted) showToast(context, 'Compte supprimé.');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return PageScaffold(
      maxWidth: 1240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Administration',
            title: 'Utilisateurs',
            subtitle: 'Invitez votre équipe et donnez à chacun le bon niveau d’accès.',
            actions: [
              GradientButton(
                label: 'Ajouter un utilisateur',
                icon: Icons.person_add_alt_rounded,
                onPressed: () => _edit(),
              ),
            ],
          ),
          if (users == null)
            _error == null
                ? const PageSkeleton()
                : EmptyState(
                    icon: Icons.cloud_off_rounded,
                    tone: Tone.danger,
                    title: 'Chargement impossible',
                    message: '$_error',
                    action: OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                  )
          else
            ..._content(context, users),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, List<AppUser> users) {
    int count(Role r) => users.where((u) => u.role == r).length;
    final disabled = users.where((u) => !u.active).length;
    final visible = users.where((u) {
      if (_role != null && u.role != _role) return false;
      if (_query.isEmpty) return true;
      return '${u.name} ${u.email}'.toLowerCase().contains(_query);
    }).toList();
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pageCount = visible.isEmpty ? 1 : (visible.length / _pageSize).ceil();
    final page = _page.clamp(1, pageCount);
    final shown = visible.skip((page - 1) * _pageSize).take(_pageSize).toList();
    final me = context.read<Session>().user?.id;

    return [
      ResponsiveGrid(
        minItemWidth: 160,
        children: [
          KpiTile(
            label: 'Comptes',
            value: fmtInt(users.length),
            caption: disabled == 0 ? 'tous actifs' : '$disabled désactivé${disabled > 1 ? 's' : ''}',
            icon: Icons.groups_2_outlined,
            tone: Tone.iris,
          ),
          for (final r in Role.values.reversed)
            KpiTile(
              label: '${r.label}s',
              value: fmtInt(count(r)),
              caption: switch (r) {
                Role.admin => 'accès complet',
                Role.editor => 'campagnes et envois',
                Role.viewer => 'consultation seule',
              },
              icon: roleIcon(r),
              tone: roleTone(r),
              progress: users.isEmpty ? 0 : count(r) / users.length,
            ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? double.infinity : 300,
            child: SearchField(
              hint: 'Rechercher un nom, un e-mail…',
              onChanged: (v) => setState(() {
                _query = v.trim().toLowerCase();
                _page = 1;
              }),
            ),
          ),
          FilterScroller(
            child: PillTabs<Role?>(
              value: _role,
              items: [
                PillTab(null, label: 'Tous', count: users.length),
                for (final r in Role.values.reversed) PillTab(r, label: '${r.label}s', count: count(r)),
              ],
              onChanged: (r) => setState(() {
                _role = r;
                _page = 1;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) const _HeaderRow(),
            if (visible.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'Aucun utilisateur',
                message: 'Modifiez la recherche ou le filtre.',
              )
            else
              for (var i = 0; i < shown.length; i++)
                _UserRow(
                  user: shown[i],
                  first: i == 0 && compact,
                  compact: compact,
                  isSelf: shown[i].id == me,
                  onEdit: () => _edit(shown[i]),
                  onReset: () => _resetPassword(shown[i]),
                  onToggle: () => _toggleActive(shown[i]),
                  onDelete: () => _delete(shown[i]),
                ),
            if (visible.length > _pageSize)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.palette.line)),
                ),
                child: Pager(
                  page: page,
                  pageSize: _pageSize,
                  total: visible.length,
                  unit: 'comptes',
                  onPage: (n) => setState(() => _page = n),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _PermissionsPanel(),
    ];
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.surfaceHigh.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('UTILISATEUR', style: style)),
          Expanded(flex: 3, child: Text('RÔLE', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          Expanded(flex: 3, child: Text('DERNIÈRE CONNEXION', style: style)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.user,
    required this.first,
    required this.compact,
    required this.isSelf,
    required this.onEdit,
    required this.onReset,
    required this.onToggle,
    required this.onDelete,
  });

  final AppUser user;
  final bool first;
  final bool compact;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final u = widget.user;
    final identity = Row(
      children: [
        UserAvatar(name: u.name, initials: u.initials, size: 38, muted: !u.active),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      u.name,
                      style: context.textTheme.titleSmall?.copyWith(color: u.active ? p.text : p.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isSelf) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Vous',
                        style: TextStyle(color: p.accent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              Text(u.email, style: context.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
    final status = u.active
        ? const StatusPill('Actif', tone: Tone.success)
        : const StatusPill('Désactivé', tone: Tone.neutral);
    final lastLogin = Text(
      u.lastLoginAt == null ? 'Jamais connecté' : fmtRelative(u.lastLoginAt),
      style: context.textTheme.bodySmall?.copyWith(color: u.lastLoginAt == null ? p.faint : p.muted),
    );

    final menu = PopupMenuButton<VoidCallback>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_horiz_rounded, color: p.muted),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        _item(context, widget.onEdit, Icons.edit_outlined, 'Modifier'),
        if (!widget.isSelf) ...[
          _item(context, widget.onReset, Icons.lock_reset_rounded, 'Réinitialiser le mot de passe'),
          _item(
            context,
            widget.onToggle,
            u.active ? Icons.person_off_outlined : Icons.person_outline_rounded,
            u.active ? 'Désactiver' : 'Réactiver',
          ),
          const PopupMenuDivider(),
          _item(context, widget.onDelete, Icons.delete_outline_rounded, 'Supprimer', danger: true),
        ] else
          _item(context, () => context.go('/account'), Icons.account_circle_outlined, 'Mon compte'),
      ],
    );

    final Widget body;
    if (widget.compact) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: identity),
              menu,
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [RoleBadge(u.role), status, lastLogin],
            ),
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(flex: 5, child: identity),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerLeft, child: RoleBadge(u.role)),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: status),
          ),
          Expanded(flex: 3, child: lastLogin),
          SizedBox(width: 48, child: menu),
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 20, 12, widget.compact ? 6 : 12, 12),
          decoration: BoxDecoration(
            color: _hover ? p.text.withValues(alpha: 0.025) : Colors.transparent,
            border: widget.first ? null : Border(top: BorderSide(color: p.line.withValues(alpha: 0.7))),
          ),
          child: body,
        ),
      ),
    );
  }

  PopupMenuItem<VoidCallback> _item(
    BuildContext context,
    VoidCallback action,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final p = context.palette;
    return PopupMenuItem(
      value: action,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: danger ? p.danger : p.muted),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: danger ? p.danger : p.text)),
        ],
      ),
    );
  }
}

/// Matrice des droits par rôle.
class _PermissionsPanel extends StatelessWidget {
  const _PermissionsPanel();

  static const _rows = <(String, Role)>[
    ('Tableau de bord, historique et journaux d’envoi', Role.viewer),
    ('Consulter les campagnes et les destinataires', Role.viewer),
    ('Créer, modifier, dupliquer et supprimer des campagnes', Role.editor),
    ('Envoyer des tests, lancer et piloter les envois', Role.editor),
    ('Marquer des destinataires envoyés / réinitialiser une table', Role.editor),
    ('Gérer les utilisateurs et leurs rôles', Role.admin),
    ('Paramètres serveur (MySQL, SMTP, valeurs par défaut)', Role.admin),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final roles = Role.values.reversed.toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            'Rôles et permissions',
            subtitle: 'Chaque rôle inclut les droits du rôle inférieur.',
            icon: Icons.admin_panel_settings_outlined,
          ),
          ResponsiveGrid(
            minItemWidth: 240,
            spacing: 12,
            children: [
              for (final r in roles)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBadge(roleIcon(r), tone: roleTone(r), size: 32),
                          const SizedBox(width: 10),
                          Text(r.label, style: context.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: Text(
                          r.description,
                          style: context.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (!compact)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.line)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('PERMISSION', style: context.textTheme.labelSmall)),
                  for (final r in roles)
                    SizedBox(
                      width: 120,
                      child: Text(
                        r.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          for (final (label, min) in _rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.line.withValues(alpha: 0.6))),
              ),
              child: compact
                  ? Row(
                      children: [
                        Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
                        const SizedBox(width: 10),
                        RoleBadge(min),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
                        for (final r in roles)
                          SizedBox(
                            width: 120,
                            child: Center(
                              child: r.includes(min)
                                  ? Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: p.success.withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check_rounded, size: 14, color: p.success),
                                    )
                                  : Icon(Icons.remove_rounded, size: 16, color: p.faint),
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _DialogResult {
  const _DialogResult(this.user, {this.password});

  final AppUser user;

  /// Mot de passe à transmettre (création ou réinitialisation).
  final String? password;
}

/// Création / modification d'un compte.
class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.api, this.user, required this.isSelf});

  final Api api;
  final AppUser? user;
  final bool isSelf;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();
  late Role _role = widget.user?.role ?? Role.editor;
  late bool _active = widget.user?.active ?? true;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.user == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) _password.text = generatePassword();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    String? problem;
    if (name.isEmpty) {
      problem = 'Le nom est obligatoire.';
    } else if (!_emailPattern.hasMatch(email)) {
      problem = 'Adresse e-mail invalide.';
    } else if (_isNew && password.length < 8) {
      problem = 'Le mot de passe doit contenir au moins 8 caractères.';
    } else if (!_isNew && password.isNotEmpty && password.length < 8) {
      problem = 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AppUser saved;
      if (_isNew) {
        saved = await widget.api.createUser({
          'name': name,
          'email': email,
          'role': _role.name,
          'password': password,
          'active': _active,
        });
      } else {
        saved = await widget.api.updateUser(widget.user!.id, {
          'name': name,
          'email': email,
          if (!widget.isSelf) 'role': _role.name,
          if (!widget.isSelf) 'active': _active,
          if (password.isNotEmpty) 'password': password,
        });
      }
      if (mounted) Navigator.pop(context, _DialogResult(saved, password: password.isEmpty ? null : password));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppDialog(
      title: _isNew ? 'Ajouter un utilisateur' : 'Modifier ${widget.user!.name}',
      subtitle: _isNew ? 'Le compte peut se connecter immédiatement avec ces identifiants.' : widget.user!.email,
      icon: _isNew ? Icons.person_add_alt_rounded : Icons.manage_accounts_outlined,
      maxWidth: 560,
      actions: [
        OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        GradientButton(
          label: _isNew ? 'Créer le compte' : 'Enregistrer',
          icon: _isNew ? Icons.check_rounded : Icons.save_outlined,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ResponsiveGrid(
            minItemWidth: 220,
            spacing: 14,
            children: [
              Field(
                label: 'Nom complet',
                child: TextField(
                  controller: _name,
                  autofocus: _isNew,
                  decoration: const InputDecoration(hintText: 'Prénom Nom'),
                ),
              ),
              Field(
                label: 'Adresse e-mail',
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'prenom.nom@fma.org.ma'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Field(
            label: 'Rôle',
            hint: widget.isSelf ? 'Vous ne pouvez pas modifier votre propre rôle.' : null,
            child: Column(
              children: [
                for (final r in Role.values.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RoleOption(
                      role: r,
                      selected: r == _role,
                      enabled: !widget.isSelf,
                      onTap: () => setState(() => _role = r),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isSelf) ...[
            const SizedBox(height: 10),
            Field(
              label: _isNew ? 'Mot de passe' : 'Nouveau mot de passe',
              hint: _isNew
                  ? 'Généré automatiquement : modifiez-le ou gardez-le, il vous sera affiché après la création.'
                  : 'Laissez vide pour conserver le mot de passe actuel.',
              child: PasswordField(controller: _password, showStrength: true, allowGenerate: true),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte actif',
                          style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _active ? 'Peut se connecter.' : 'Connexion bloquée, sessions fermées.',
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            InfoBanner(tone: Tone.danger, icon: Icons.error_outline_rounded, text: _error!),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.role, required this.selected, required this.enabled, required this.onTap});

  final Role role;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = roleTone(role).of(context);
    return Opacity(
      opacity: enabled || selected ? 1 : 0.45,
      child: Material(
        color: selected ? c.withValues(alpha: 0.08) : p.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: selected ? c.withValues(alpha: 0.6) : p.line, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMd),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBadge(roleIcon(role), tone: roleTone(role), size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label, style: context.textTheme.titleSmall),
                      Text(role.description, style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c : Colors.transparent,
                    border: Border.all(color: selected ? c : p.lineStrong, width: 1.5),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
