import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../services/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'navigation.dart';

class _Command {
  const _Command({
    required this.label,
    required this.icon,
    required this.group,
    required this.run,
    this.hint,
    this.keywords = '',
  });

  final String label;
  final IconData icon;
  final String group;
  final String? hint;
  final String keywords;
  final VoidCallback run;
}

bool _open = false;

/// Palette de commandes (Ctrl+K) : navigation, actions et recherche de campagnes.
Future<void> showCommandPalette(BuildContext context) async {
  if (_open) return;
  _open = true;
  final router = GoRouter.of(context);
  final session = context.read<Session>();
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: context.isDark ? 0.55 : 0.3),
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (context, _, _) => _CommandPalette(router: router, session: session),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
        );
      },
    );
  } finally {
    _open = false;
  }
}

String _normalize(String s) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ’';
  const to = 'aaaaaeeeeiiiiooooouuuucn\'';
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i == -1 ? ch : to[i]);
  }
  return buffer.toString();
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.router, required this.session});

  final GoRouter router;
  final Session session;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  List<Campaign> _campaigns = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _selected = 0));
    widget.session.api.campaigns().then((list) {
      if (mounted) setState(() => _campaigns = list);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(String path) {
    Navigator.of(context).pop();
    widget.router.go(path);
  }

  List<_Command> get _all {
    final s = widget.session;
    return [
      for (final d in visibleDestinations(s))
        _Command(
          label: d.label,
          icon: d.icon,
          group: 'Navigation',
          hint: 'Aller à',
          keywords: d.keywords,
          run: () => _go(d.path),
        ),
      _Command(
        label: 'Mon compte',
        icon: Icons.account_circle_outlined,
        group: 'Navigation',
        hint: 'Aller à',
        keywords: 'profil mot de passe compte',
        run: () => _go('/account'),
      ),
      if (s.canEdit)
        _Command(
          label: 'Nouvelle campagne',
          icon: Icons.add_rounded,
          group: 'Actions',
          keywords: 'creer ajouter email',
          run: () => _go('/campaigns/new'),
        ),
      if (s.isAdmin)
        _Command(
          label: 'Ajouter un utilisateur',
          icon: Icons.person_add_alt_rounded,
          group: 'Actions',
          keywords: 'inviter compte equipe',
          run: () => _go('/users?new=1'),
        ),
      for (final (mode, label, icon) in const [
        (ThemeMode.dark, 'Thème sombre', Icons.dark_mode_outlined),
        (ThemeMode.light, 'Thème clair', Icons.light_mode_outlined),
        (ThemeMode.system, 'Thème du système', Icons.contrast_rounded),
      ])
        _Command(
          label: label,
          icon: icon,
          group: 'Actions',
          hint: s.themeMode == mode ? 'Actif' : null,
          keywords: 'apparence mode theme',
          run: () {
            Navigator.of(context).pop();
            s.setThemeMode(mode);
          },
        ),
      _Command(
        label: 'Se déconnecter',
        icon: Icons.logout_rounded,
        group: 'Actions',
        keywords: 'deconnexion quitter logout',
        run: () {
          Navigator.of(context).pop();
          s.signOut();
        },
      ),
      for (final c in _campaigns)
        _Command(
          label: c.name,
          icon: Icons.campaign_outlined,
          group: 'Campagnes',
          hint: c.table,
          keywords: '${c.subject} ${c.table}',
          run: () => _go('/campaigns/${c.id}'),
        ),
    ];
  }

  List<_Command> _filtered() {
    final words = _normalize(_query.text.trim()).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final all = _all;
    if (words.isEmpty) {
      return all.where((c) => c.group != 'Campagnes').toList() +
          all.where((c) => c.group == 'Campagnes').take(5).toList();
    }
    return all.where((c) {
      final haystack = _normalize('${c.label} ${c.keywords} ${c.group}');
      return words.every(haystack.contains);
    }).toList();
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count);
    // Garde la ligne sélectionnée visible (hauteur de ligne ≈ 48).
    final target = _selected * 48.0;
    if (_scroll.hasClients) {
      final viewport = _scroll.position.viewportDimension;
      if (target < _scroll.offset || target + 48 > _scroll.offset + viewport) {
        _scroll.animateTo(
          (target - viewport / 2).clamp(0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final commands = _filtered();
    final width = MediaQuery.sizeOf(context).width;
    final rows = <Widget>[];
    String? group;
    for (var i = 0; i < commands.length; i++) {
      final c = commands[i];
      if (c.group != group) {
        group = c.group;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(group, style: context.textTheme.labelSmall?.copyWith(color: p.faint)),
          ),
        );
      }
      rows.add(_row(context, c, i == _selected));
    }

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width < 680 ? width - 32 : 620,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(radiusXl),
              border: Border.all(color: p.lineStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.6 : 0.18),
                  blurRadius: 60,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, commands.length),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, commands.length),
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: p.faint, size: 21),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            autofocus: true,
                            style: context.textTheme.bodyLarge?.copyWith(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Rechercher une page, une action, une campagne…',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                            ),
                            onSubmitted: (_) {
                              if (commands.isNotEmpty) commands[_selected.clamp(0, commands.length - 1)].run();
                            },
                          ),
                        ),
                        const Kbd('Échap'),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: p.line),
                  Flexible(
                    child: commands.isEmpty
                        ? const EmptyState(icon: Icons.search_off_rounded, title: 'Aucun résultat')
                        : ListView(
                            controller: _scroll,
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            children: rows,
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.surfaceHigh,
                      border: Border(top: BorderSide(color: p.line)),
                    ),
                    child: Row(
                      children: [
                        const Kbd('↑'),
                        const SizedBox(width: 4),
                        const Kbd('↓'),
                        const SizedBox(width: 8),
                        Text('naviguer', style: context.textTheme.bodySmall),
                        const SizedBox(width: 16),
                        const Kbd('Entrée'),
                        const SizedBox(width: 8),
                        Text('ouvrir', style: context.textTheme.bodySmall),
                        const Spacer(),
                        Text('Mailler Studio', style: context.textTheme.bodySmall?.copyWith(color: p.faint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Command c, bool selected) {
    final p = context.palette;
    return SizedBox(
      height: 48,
      child: Material(
        color: selected ? p.accent.withValues(alpha: context.isDark ? 0.14 : 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMd),
          onTap: c.run,
          onHover: (h) {
            if (h) {
              final index = _filtered().indexOf(c);
              if (index != -1 && index != _selected) setState(() => _selected = index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? p.accent.withValues(alpha: 0.18) : p.surfaceHigh,
                    borderRadius: BorderRadius.circular(radiusSm),
                    border: Border.all(color: selected ? p.accent.withValues(alpha: 0.3) : p.line),
                  ),
                  child: Icon(c.icon, size: 16, color: selected ? p.accent : p.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (c.hint != null) Text(c.hint!, style: context.textTheme.bodySmall?.copyWith(color: p.faint)),
                if (selected) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.keyboard_return_rounded, size: 15, color: p.faint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
