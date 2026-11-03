import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Mon compte : profil, mot de passe, préférences d'affichage, session.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();
    return PageScaffold(
      maxWidth: 1080,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            eyebrow: 'Compte',
            title: 'Mon compte',
            subtitle: 'Votre profil, votre mot de passe et vos préférences.',
          ),
          _ProfileHero(),
          const SizedBox(height: 16),
          if (user.service)
            const InfoBanner(
              tone: Tone.warning,
              icon: Icons.key_rounded,
              text: 'Connecté avec le jeton de service : il n’a ni profil ni mot de passe modifiables.',
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 860;
                const profile = _ProfileForm();
                const password = _PasswordForm();
                if (!wide) return const Column(children: [profile, SizedBox(height: 16), password]);
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: profile),
                    SizedBox(width: 16),
                    Expanded(child: password),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const _PreferencesPanel(),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<Session>().user!;
    return Panel(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.accent.withValues(alpha: 0.16), p.iris.withValues(alpha: 0.05), Colors.transparent],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                UserAvatar(name: user.name, initials: user.initials, size: 72),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.name, style: context.textTheme.headlineSmall),
                    if (user.email.isNotEmpty)
                      Text(user.email, style: context.textTheme.bodyMedium?.copyWith(color: p.muted)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RoleBadge(user.role),
                        if (user.createdAt != null)
                          StatusPill(
                            'Membre depuis ${fmtDateTime(user.createdAt).split(' · ').first}',
                            icon: Icons.calendar_today_outlined,
                          ),
                        if (user.lastLoginAt != null)
                          StatusPill('Connecté ${fmtRelative(user.lastLoginAt)}', icon: Icons.login_rounded),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm();

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final Session _session = context.read<Session>();
  late final _name = TextEditingController(text: _session.user?.name ?? '');
  late final _email = TextEditingController(text: _session.user?.email ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showToast(context, 'Le nom est obligatoire.', error: true);
    if (!_emailPattern.hasMatch(_email.text.trim())) return showToast(context, 'Adresse e-mail invalide.', error: true);
    setState(() => _busy = true);
    try {
      final user = await _session.api.updateMe(name: _name.text.trim(), email: _email.text.trim());
      _session.updateUser(user);
      if (mounted) showToast(context, 'Profil mis à jour.');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Profil', subtitle: 'Nom affiché et adresse de connexion', icon: Icons.badge_outlined),
        Field(
          label: 'Nom complet',
          child: TextField(controller: _name),
        ),
        const SizedBox(height: 14),
        Field(
          label: 'Adresse e-mail',
          hint: 'Sert d’identifiant de connexion.',
          child: TextField(controller: _email, keyboardType: TextInputType.emailAddress),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Enregistrer'),
          ),
        ),
      ],
    ),
  );
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) return showToast(context, 'Saisissez votre mot de passe actuel.', error: true);
    if (_next.text.length < 8) {
      return showToast(context, 'Le nouveau mot de passe doit contenir 8 caractères minimum.', error: true);
    }
    if (_next.text != _confirm.text) {
      return showToast(context, 'Les deux mots de passe ne correspondent pas.', error: true);
    }
    final session = context.read<Session>();
    setState(() => _busy = true);
    try {
      final result = await session.api.changePassword(_current.text, _next.text);
      await session.replaceSession(result);
      for (final c in [_current, _next, _confirm]) {
        c.clear();
      }
      if (mounted) showToast(context, 'Mot de passe modifié. Vos autres sessions ont été fermées.');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Mot de passe',
          subtitle: 'Les autres appareils seront déconnectés',
          icon: Icons.lock_outline_rounded,
        ),
        Field(
          label: 'Mot de passe actuel',
          child: PasswordField(controller: _current, autofillHints: const [AutofillHints.password]),
        ),
        const SizedBox(height: 14),
        Field(
          label: 'Nouveau mot de passe',
          child: PasswordField(
            controller: _next,
            showStrength: true,
            allowGenerate: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
        ),
        const SizedBox(height: 14),
        Field(
          label: 'Confirmer',
          child: PasswordField(controller: _confirm, onSubmitted: (_) => _save()),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Changer le mot de passe'),
          ),
        ),
      ],
    ),
  );
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final p = context.palette;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Préférences et session', icon: Icons.tune_rounded),
          Wrap(
            spacing: 24,
            runSpacing: 18,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Apparence', style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  PillTabs<ThemeMode>(
                    value: session.themeMode,
                    items: const [
                      PillTab(ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Sombre'),
                      PillTab(ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Clair'),
                      PillTab(ThemeMode.system, icon: Icons.contrast_rounded, label: 'Système'),
                    ],
                    onChanged: session.setThemeMode,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Serveur', style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(session.serverUrl, style: monoStyle(size: 12.5, color: p.muted)),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.danger,
                  side: BorderSide(color: p.danger.withValues(alpha: 0.35)),
                ),
                onPressed: session.signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
