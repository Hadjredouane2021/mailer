import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../services/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'command_palette.dart';
import 'common.dart';
import 'navigation.dart';

const _wideBreakpoint = 1120.0;
const _compactBreakpoint = 720.0;

/// Coque de l'application : barre latérale flottante (large), rail (moyen), dock (mobile).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  // Ctrl+K / Cmd+K, quel que soit l'élément qui a le focus.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    if (mounted) showCommandPalette(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final location = widget.location;
    final content = ClipRect(child: widget.child);

    Widget layout;
    if (width >= _compactBreakpoint) {
      final expanded = width >= _wideBreakpoint;
      layout = Row(
        children: [
          _Sidebar(location: location, expanded: expanded),
          Expanded(
            child: Column(
              children: [
                _TopBar(location: location),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      );
    } else {
      layout = Stack(
        children: [
          Column(
            children: [
              _MobileTopBar(location: location),
              Expanded(child: content),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _MobileDock(location: location)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(child: SafeArea(bottom: false, child: layout)),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Barre latérale

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, required this.expanded});

  final String location;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = context.watch<Session>();
    final active = destinationFor(location);
    final dests = visibleDestinations(session);
    final workspace = dests.where((d) => !d.admin).toList();
    final admin = dests.where((d) => d.admin).toList();

    Widget label(String text) => expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
            child: Text(text, style: context.textTheme.labelSmall?.copyWith(color: p.faint)),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            child: Divider(color: p.line),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? 268 : 88,
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: Glass(
        radius: 22,
        padding: EdgeInsets.fromLTRB(expanded ? 14 : 12, 18, expanded ? 14 : 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(expanded: expanded),
            const SizedBox(height: 22),
            if (session.canEdit)
              expanded
                  ? GradientButton(
                      label: 'Nouvelle campagne',
                      icon: Icons.add_rounded,
                      expand: true,
                      onPressed: () => context.go('/campaigns/new'),
                    )
                  : Tooltip(
                      message: 'Nouvelle campagne',
                      child: GradientButton(
                        label: '',
                        icon: Icons.add_rounded,
                        onPressed: () => context.go('/campaigns/new'),
                      ),
                    ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label('Espace de travail'),
                    for (final d in workspace) _NavItem(dest: d, selected: d == active, expanded: expanded),
                    if (admin.isNotEmpty) ...[
                      label('Administration'),
                      for (final d in admin) _NavItem(dest: d, selected: d == active, expanded: expanded),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (expanded)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: p.line),
                ),
                child: const Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: PartnerLogos(height: 30, gap: 12, vertical: true)),
                ),
              ),
            _UserMenu(expanded: expanded),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return const Center(child: BrandMark(size: 38));
    return Row(
      children: [
        const BrandMark(size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mailler Studio', style: context.textTheme.titleMedium?.copyWith(letterSpacing: -0.4)),
              Text(
                'FMA · RDV de l’Assurance',
                style: context.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.dest, required this.selected, required this.expanded});

  final NavDest dest;
  final bool selected;
  final bool expanded;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = widget.selected;
    final dest = widget.dest;
    final live = dest.path == '/history' ? context.watch<ServerStatus>().liveJobs.length : 0;
    final color = selected ? p.text : (_hover ? p.text : p.muted);

    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(dest.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 3),
          padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 12 : 0, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? p.accent.withValues(alpha: context.isDark ? 0.14 : 0.1)
                : (_hover ? p.text.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: selected ? p.accent.withValues(alpha: 0.22) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: !widget.expanded && live > 0,
                backgroundColor: p.info,
                smallSize: 8,
                child: Icon(selected ? dest.activeIcon : dest.icon, size: 20, color: selected ? p.accent : color),
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dest.label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (live > 0) StatusPill('$live', tone: Tone.info, pulse: true),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.expanded ? item : Tooltip(message: dest.label, preferBelow: false, child: item);
  }
}

/// Carte utilisateur en bas de la barre latérale, avec menu.
class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<Session>().user;
    if (user == null) return const SizedBox.shrink();
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: accountMenuItems(context),
      builder: (context, controller, _) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMd),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            padding: EdgeInsets.all(expanded ? 10 : 6),
            decoration: BoxDecoration(
              color: expanded ? p.surfaceHigh.withValues(alpha: 0.7) : null,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: expanded ? p.line : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                UserAvatar(name: user.name, initials: user.initials, size: 34),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(user.role.label, style: context.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded, size: 18, color: p.faint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrées du menu compte (barre latérale et barre mobile).
List<Widget> accountMenuItems(BuildContext context) {
  final session = context.read<Session>();
  final user = session.user;
  final p = context.palette;
  return [
    if (user != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (user.email.isNotEmpty) Text(user.email, style: context.textTheme.bodySmall),
            const SizedBox(height: 8),
            RoleBadge(user.role),
          ],
        ),
      ),
    const Divider(height: 9),
    MenuItemButton(
      leadingIcon: const Icon(Icons.account_circle_outlined, size: 19),
      onPressed: () => context.go('/account'),
      child: const Text('Mon compte'),
    ),
    MenuItemButton(
      leadingIcon: const Icon(Icons.search_rounded, size: 19),
      trailingIcon: const Kbd('Ctrl K'),
      onPressed: () => showCommandPalette(context),
      child: const Text('Recherche rapide'),
    ),
    SubmenuButton(
      leadingIcon: const Icon(Icons.palette_outlined, size: 19),
      menuChildren: [
        for (final (mode, label, icon) in const [
          (ThemeMode.dark, 'Sombre', Icons.dark_mode_outlined),
          (ThemeMode.light, 'Clair', Icons.light_mode_outlined),
          (ThemeMode.system, 'Système', Icons.contrast_rounded),
        ])
          MenuItemButton(
            leadingIcon: Icon(icon, size: 18),
            trailingIcon: session.themeMode == mode ? Icon(Icons.check_rounded, size: 18, color: p.accent) : null,
            onPressed: () => session.setThemeMode(mode),
            child: Text(label),
          ),
      ],
      child: const Text('Apparence'),
    ),
    const Divider(height: 9),
    MenuItemButton(
      leadingIcon: Icon(Icons.logout_rounded, size: 19, color: p.danger),
      onPressed: session.signOut,
      child: Text('Se déconnecter', style: TextStyle(color: p.danger)),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────── Barre supérieure

class _TopBar extends StatelessWidget {
  const _TopBar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 20, 0),
        child: Row(
          children: [
            Text('Mailler Studio', style: context.textTheme.bodyMedium?.copyWith(color: p.faint)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: p.faint),
            ),
            Flexible(
              child: Text(
                titleFor(location),
                style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            const _LiveChip(),
            const SizedBox(width: 10),
            if (width >= 900) ...[
              const _SearchPill(),
              const SizedBox(width: 10),
            ] else ...[
              IconButton(
                tooltip: 'Recherche rapide (Ctrl K)',
                onPressed: () => showCommandPalette(context),
                icon: const Icon(Icons.search_rounded, size: 20),
              ),
            ],
            const ThemeToggle(),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface.withValues(alpha: context.isDark ? 0.6 : 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: BorderSide(color: p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMd),
        onTap: () => showCommandPalette(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18, color: p.faint),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Text('Rechercher…', style: context.textTheme.bodyMedium?.copyWith(color: p.faint)),
              ),
              const Kbd('Ctrl K'),
            ],
          ),
        ),
      ),
    );
  }
}

/// État du serveur ou envois en cours (lien vers la console).
class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ServerStatus>();
    final jobs = status.liveJobs;
    if (!status.reachable) return const StatusPill('API hors ligne', tone: Tone.danger);
    if (status.health != null && !status.health!.database) {
      return const StatusPill('MySQL indisponible', tone: Tone.danger);
    }
    final dry = status.health?.dryRun ?? false;
    final children = <Widget>[
      if (dry)
        const Tooltip(
          message: 'MAIL_DRY_RUN=1 : aucun e-mail ne part réellement',
          child: StatusPill('Simulation', tone: Tone.warning),
        ),
      if (jobs.isNotEmpty)
        InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => context.go('/jobs/${jobs.first.id}'),
          child: StatusPill(
            jobs.length == 1 ? 'Envoi en cours · ${jobs.first.campaignName}' : '${jobs.length} envois en cours',
            tone: Tone.info,
            pulse: true,
          ),
        )
      else if (!dry)
        const StatusPill('En ligne', tone: Tone.success),
    ];
    return Wrap(spacing: 8, children: children);
  }
}

/// Bascule sombre → clair → système.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final (next, icon, tip) = switch (session.themeMode) {
      ThemeMode.dark => (ThemeMode.light, Icons.dark_mode_outlined, 'Thème sombre'),
      ThemeMode.light => (ThemeMode.system, Icons.light_mode_outlined, 'Thème clair'),
      ThemeMode.system => (ThemeMode.dark, Icons.contrast_rounded, 'Thème du système'),
    };
    return IconButton(
      tooltip: '$tip · cliquer pour changer',
      onPressed: () => session.setThemeMode(next),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: Icon(icon, key: ValueKey(icon), size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Mobile

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    final live = context.watch<ServerStatus>().liveJobs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
      child: Row(
        children: [
          const BrandMark(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(titleFor(location), style: context.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
          ),
          if (live.isNotEmpty)
            IconButton(
              tooltip: 'Envoi en cours',
              onPressed: () => context.go('/jobs/${live.first.id}'),
              icon: PulseDot(color: context.palette.info, size: 9),
            ),
          IconButton(
            tooltip: 'Rechercher',
            onPressed: () => showCommandPalette(context),
            icon: const Icon(Icons.search_rounded, size: 22),
          ),
          if (user != null)
            MenuAnchor(
              alignmentOffset: const Offset(-160, 6),
              menuChildren: accountMenuItems(context),
              builder: (context, controller, _) => IconButton(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: UserAvatar(name: user.name, initials: user.initials, size: 32),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileDock extends StatelessWidget {
  const _MobileDock({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final active = destinationFor(location);
    final main = destinations.where((d) => !d.admin).toList();
    final extra = visibleDestinations(session).where((d) => d.admin).toList();
    final moreActive = active != null && active.admin || location.startsWith('/account');
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Glass(
            radius: 26,
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (final d in main)
                  Expanded(
                    child: _DockItem(
                      icon: d == active ? d.activeIcon : d.icon,
                      label: d.label.split(' ').first,
                      selected: d == active,
                      onTap: () => context.go(d.path),
                    ),
                  ),
                Expanded(
                  child: _DockItem(
                    icon: Icons.more_horiz_rounded,
                    label: 'Plus',
                    selected: moreActive,
                    onTap: () => _showMore(context, extra),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, List<NavDest> extra) {
    final session = context.read<Session>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) {
        final p = sheet.palette;
        Widget tile(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? p.muted),
          title: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          onTap: () {
            Navigator.pop(sheet);
            onTap();
          },
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in extra) tile(d.icon, d.label, () => context.go(d.path)),
                tile(Icons.account_circle_outlined, 'Mon compte', () => context.go('/account')),
                if (session.canEdit) tile(Icons.add_rounded, 'Nouvelle campagne', () => context.go('/campaigns/new')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Consumer<Session>(
                    builder: (context, s, _) => PillTabs<ThemeMode>(
                      expand: true,
                      value: s.themeMode,
                      items: const [
                        PillTab(ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Sombre'),
                        PillTab(ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Clair'),
                        PillTab(ThemeMode.system, icon: Icons.contrast_rounded, label: 'Auto'),
                      ],
                      onChanged: s.setThemeMode,
                    ),
                  ),
                ),
                tile(Icons.logout_rounded, 'Se déconnecter', session.signOut, color: p.danger),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: FittedBox(fit: BoxFit.scaleDown, child: PartnerLogos(height: 24)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: context.isDark ? 0.16 : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: selected ? p.accent : p.muted),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: selected ? p.text : p.muted,
                letterSpacing: 0,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Conteneur standard des pages : défilement, marges et largeur maximale.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child, this.maxWidth = 1320});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < _compactBreakpoint;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, compact ? 14 : 10, compact ? 16 : 28, compact ? 120 : 48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: FadeIn(child: child),
        ),
      ),
    );
  }
}

/// Raccourci : rôle de l'utilisateur connecté.
extension SessionRole on BuildContext {
  bool get canEdit => read<Session>().canEdit;
  Role? get role => read<Session>().user?.role;
}
