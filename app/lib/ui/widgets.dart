import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Tonalités sémantiques utilisées par les pastilles, jauges et icônes.
enum Tone { neutral, accent, iris, wine, success, danger, warning, info }

extension ToneColor on Tone {
  Color of(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      Tone.neutral => p.muted,
      Tone.accent => p.accent,
      Tone.iris => p.iris,
      Tone.wine => p.wine,
      Tone.success => p.success,
      Tone.danger => p.danger,
      Tone.warning => p.warning,
      Tone.info => p.info,
    };
  }
}

// ─────────────────────────────────────────────────────────────── Fond & surfaces

/// Fond de l'application : halos très doux + trame de points qui s'estompe.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final strength = context.isDark ? 0.14 : 0.09;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.bg),
      child: Stack(
        children: [
          Positioned(
            top: -380,
            left: -260,
            child: _Glow(color: p.accent.withValues(alpha: strength), size: 900),
          ),
          Positioned(
            top: -420,
            right: -320,
            child: _Glow(color: p.iris.withValues(alpha: strength * 0.55), size: 860),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _DotGridPainter(p.text.withValues(alpha: context.isDark ? 0.07 : 0.08))),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Trame de points en haut de l'écran, qui disparaît vers le bas.
class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 22.0;
    const fade = 420.0;
    final paint = Paint();
    final rows = math.min(size.height, fade) ~/ gap;
    for (var r = 0; r <= rows; r++) {
      final y = r * gap + 8;
      final alpha = (1 - y / fade).clamp(0.0, 1.0);
      if (alpha <= 0) break;
      paint.color = color.withValues(alpha: color.a * alpha);
      for (var x = 8.0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

/// Surface flottante translucide (flou d'arrière-plan).
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = radiusXl, this.padding, this.blur = 24});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: shape,
              border: Border.all(color: p.line),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Carte de base : surface, bordure fine, reflet discret ; s'éclaire au survol si cliquable.
class Panel extends StatefulWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.glow,
    this.color,
    this.radius = radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? glow;
  final Color? color;
  final double radius;

  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    final radius = BorderRadius.circular(widget.radius);
    final glow = widget.glow;
    final interactive = widget.onTap != null;
    final borderColor = glow != null ? glow.withValues(alpha: 0.4) : (_hover && interactive ? p.lineStrong : p.line);

    return MouseRegion(
      onEnter: interactive ? (_) => setState(() => _hover = true) : null,
      onExit: interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover && interactive ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (glow != null) BoxShadow(color: glow.withValues(alpha: 0.16), blurRadius: 48, spreadRadius: -6),
            if (!dark) ...[
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1)),
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover && interactive ? 0.08 : 0.04),
                blurRadius: _hover && interactive ? 28 : 18,
                offset: const Offset(0, 8),
              ),
            ],
            if (dark && _hover && interactive)
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: Material(
          color: widget.color ?? p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: dark
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.025), Colors.white.withValues(alpha: 0)],
                      stops: const [0, 0.4],
                    ),
                  )
                : null,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo : carré arrondi au dégradé de marque.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.3),
      gradient: Palette.brand,
      boxShadow: [
        BoxShadow(
          color: Palette.brandGlow.withValues(alpha: 0.35),
          blurRadius: size * 0.5,
          offset: Offset(0, size * 0.15),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                stops: const [0, 0.55],
              ),
            ),
          ),
        ),
        Icon(Icons.send_rounded, color: Colors.white, size: size * 0.46),
      ],
    ),
  );
}

/// Logos FMA et Rendez-vous de Casablanca de l'Assurance, version claire ou sombre selon le thème.
/// [dark] force une version (panneaux toujours sombres) ; [height] = hauteur du logo FMA ;
/// [vertical] empile les deux logos (colonnes étroites).
class PartnerLogos extends StatelessWidget {
  const PartnerLogos({super.key, this.height = 24, this.dark, this.gap = 14, this.vertical = false});

  final double height;
  final bool? dark;
  final double gap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? context.isDark;
    final suffix = isDark ? '-dark' : '';
    final divider = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.12);
    // Les deux logos n'ont pas les mêmes proportions : le RDV est un peu plus haut pour un poids visuel équivalent.
    final fma = Image.asset(
      'assets/logos/fma$suffix.png',
      height: height,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Fédération Marocaine de l’Assurance',
    );
    final rdv = Image.asset(
      'assets/logos/rdv$suffix.png',
      height: height * 1.4,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Rendez-vous de Casablanca de l’Assurance',
    );
    final logos = vertical
        ? Column(
            key: ValueKey(isDark),
            mainAxisSize: MainAxisSize.min,
            children: [
              fma,
              Container(width: height * 2, height: 1, margin: EdgeInsets.symmetric(vertical: gap * 0.8), color: divider),
              rdv,
            ],
          )
        : Row(
            key: ValueKey(isDark),
            mainAxisSize: MainAxisSize.min,
            children: [
              fma,
              Container(width: 1, height: height * 1.15, margin: EdgeInsets.symmetric(horizontal: gap), color: divider),
              rdv,
            ],
          );
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: logos);
  }
}

// ─────────────────────────────────────────────────────────────── En-têtes

/// Petite étiquette au-dessus d'un titre.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.tone = Tone.accent, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 6)],
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// En-tête de page : étiquette, titre, sous-titre et actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.trailingTitle,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? trailingTitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Eyebrow(eyebrow!)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(title, style: context.textTheme.headlineMedium?.copyWith(fontSize: compact ? 25 : 30)),
            ),
            if (trailingTitle != null) ...[const SizedBox(width: 12), trailingTitle!],
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(subtitle!, style: context.textTheme.bodyMedium?.copyWith(color: p.muted)),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 20 : 28),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Flexible(child: heading),
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing, this.icon});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: context.palette.muted), const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleMedium),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: context.textTheme.bodySmall),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────── Indicateurs

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.tone = Tone.accent, this.size = 40});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: size * 0.48, color: c),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = Tone.neutral, this.pulse = false, this.icon});

  final String label;
  final Tone tone;
  final bool pulse;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 13, color: c) else pulse ? PulseDot(color: c) : _Dot(color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Point avec onde animée (activité en direct).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + _c.value * 1.8,
            child: _Dot(
              color: widget.color.withValues(alpha: (1 - _c.value) * 0.55),
              size: widget.size,
            ),
          ),
          _Dot(color: widget.color, size: widget.size),
        ],
      ),
    ),
  );
}

/// Jauge horizontale à dégradé.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.tone = Tone.accent, this.height = 8});

  final double value;
  final Tone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    final p = context.palette;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final second = tone == Tone.accent ? Color.lerp(p.accent, p.iris, 0.55)! : c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.surfaceHigh)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, w, _) => FractionallySizedBox(
                widthFactor: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(colors: [c, second]),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anneau de progression animé.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 168,
    this.stroke = 14,
    this.tone = Tone.accent,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Tone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.isNaN ? 0 : value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            color: c,
            secondary: tone == Tone.accent ? p.iris : c.withValues(alpha: 0.6),
            track: p.surfaceHigh,
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.secondary,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color secondary;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [color, secondary, color],
        stops: const [0, 0.5, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.secondary != secondary;
}

/// Tuile chiffre-clé (bento) : libellé, valeur, légende, et jauge ou courbe de tendance.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    required this.icon,
    this.tone = Tone.accent,
    this.progress,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Tone tone;
  final double? progress;
  final List<double>? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    Widget footer;
    if (trend != null && trend!.any((v) => v > 0)) {
      footer = SizedBox(
        height: 34,
        child: Sparkline(values: trend!, color: c),
      );
    } else if (progress != null) {
      footer = Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Meter(value: progress!, tone: tone, height: 6),
      );
    } else {
      // Emplacement réservé : toutes les tuiles d'une rangée gardent la même hauteur.
      footer = const SizedBox(height: 34);
    }
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: c),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.textTheme.headlineMedium?.copyWith(
                fontFeatures: tabularFigures,
                fontSize: 32,
                letterSpacing: -1.4,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(caption ?? ' ', style: context.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

/// Petit couple libellé / valeur.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.tone, this.align = CrossAxisAlignment.start});

  final String label;
  final String value;
  final Tone? tone;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(
        value,
        style: context.textTheme.titleLarge?.copyWith(
          color: tone?.of(context),
          fontFeatures: tabularFigures,
          letterSpacing: -0.6,
        ),
      ),
    ],
  );
}

/// Pastille d'initiales, couleur stable dérivée du nom.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, required this.initials, this.size = 36, this.muted = false});

  final String name;
  final String initials;
  final double size;
  final bool muted;

  static const _hues = [213.0, 168.0, 341.0, 200.0, 186.0, 226.0, 155.0, 330.0];

  @override
  Widget build(BuildContext context) {
    final hue = _hues[name.codeUnits.fold<int>(0, (a, c) => a + c) % _hues.length];
    final a = HSLColor.fromAHSL(1, hue, 0.75, 0.6).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 32) % 360, 0.8, 0.45).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: muted ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
        color: muted ? context.palette.surfaceHigh : null,
        border: Border.all(color: Colors.white.withValues(alpha: muted ? 0 : 0.18)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: muted ? context.palette.faint : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Raccourci clavier (Ctrl K…).
class Kbd extends StatelessWidget {
  const Kbd(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      child: Text(
        label,
        style: monoStyle(size: 11, color: p.muted, weight: FontWeight.w500),
      ),
    );
  }
}

/// Bandeau d'information / d'erreur.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.tone, required this.icon, required this.text, this.action});

  final Tone tone;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(color: c, fontWeight: FontWeight.w500),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Actions

/// Bouton d'action principal au dégradé de marque, avec halo.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(radiusMd);
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: Colors.white),
        if ((widget.loading || widget.icon != null) && widget.label.isNotEmpty) const SizedBox(width: 8),
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
            ),
          ),
      ],
    );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || widget.loading ? 1 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.compact ? 38 : 44,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: Palette.brand,
            boxShadow: [
              BoxShadow(
                color: Palette.brandGlow.withValues(alpha: _hover && enabled ? 0.5 : 0.28),
                blurRadius: _hover && enabled ? 26 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? widget.onPressed : null,
              hoverColor: Colors.white.withValues(alpha: 0.08),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
                    stops: const [0, 0.6],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.label.isEmpty ? 12 : (widget.compact ? 14 : 18)),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Chargement & vide

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = radiusSm});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 3 - 1;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [p.surfaceHigh, Color.lerp(p.surfaceHigh, p.lineStrong, 0.7)!, p.surfaceHigh],
            ),
          ),
        );
      },
    );
  }
}

/// Squelette de page générique pendant le premier chargement.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Skeleton(height: 22, width: 110, radius: 99),
      SizedBox(height: 14),
      Skeleton(height: 34, width: 320),
      SizedBox(height: 30),
      Row(
        children: [
          Expanded(child: Skeleton(height: 140, radius: radiusLg)),
          SizedBox(width: 16),
          Expanded(child: Skeleton(height: 140, radius: radiusLg)),
          SizedBox(width: 16),
          Expanded(child: Skeleton(height: 140, radius: radiusLg)),
        ],
      ),
      SizedBox(height: 16),
      Skeleton(height: 300, radius: radiusLg),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.tone = Tone.accent,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = tone.of(context);
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0)]),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: p.lineStrong),
                  ),
                  child: Icon(icon, size: 21, color: c),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: context.textTheme.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, style: context.textTheme.bodySmall, textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Charge des données, garde l'affichage pendant les rafraîchissements
/// et peut se recharger périodiquement (tableau de bord, console d'envoi).
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.refreshEvery, this.skeleton});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Duration? refreshEvery;
  final Widget? skeleton;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.refreshEvery != null) {
      _timer = Timer.periodic(widget.refreshEvery!, (_) => _reload(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent || _data == null) setState(() => _error = e);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(context, data, _reload);
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: Tone.danger,
        title: 'Chargement impossible',
        message: '$_error',
        action: OutlinedButton.icon(
          onPressed: () {
            setState(() => _error = null);
            _reload();
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réessayer'),
        ),
      );
    }
    return widget.skeleton ?? const PageSkeleton();
  }
}

/// Apparition douce (fondu + léger glissement), avec délai pour les entrées en cascade.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(offset: Offset(0, (1 - _curve.value) * widget.offset), child: child),
    ),
  );
}

// ─────────────────────────────────────────────────────────────── Formulaires & mise en page

/// Champ de formulaire avec libellé au-dessus.
class Field extends StatelessWidget {
  const Field({super.key, required this.label, required this.child, this.hint, this.trailing});

  final String label;
  final Widget child;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 1, bottom: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.palette.text.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
      child,
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(left: 1, top: 6),
          child: Text(hint!, style: context.textTheme.bodySmall),
        ),
    ],
  );
}

/// Grille responsive simple : nombre de colonnes selon la largeur disponible.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 300, this.spacing = 16});

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final fit = math.max(1, ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor());
      final columns = math.min(fit, math.max(1, children.length));
      final width = (c.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

class PillTab<T> {
  const PillTab(this.value, {this.label, this.icon, this.tooltip, this.count});

  final T value;
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final int? count;
}

/// Contrôle segmenté (filtres, modes d'aperçu, thème).
class PillTabs<T> extends StatelessWidget {
  const PillTabs({super.key, required this.value, required this.items, required this.onChanged, this.expand = false});

  final T value;
  final List<PillTab<T>> items;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pills = [for (final item in items) _maybeExpand(_pill(context, item, item.value == value))];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: p.line),
      ),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: pills),
    );
  }

  Widget _maybeExpand(Widget child) => expand ? Expanded(child: child) : child;

  Widget _pill(BuildContext context, PillTab<T> item, bool selected) {
    final p = context.palette;
    final color = selected ? p.text : p.muted;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(horizontal: item.label == null ? 10 : 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? p.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(radiusSm + 1),
        boxShadow: selected && !context.isDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.icon != null) Icon(item.icon, size: 16, color: selected ? p.accent : color),
          if (item.icon != null && item.label != null) const SizedBox(width: 7),
          if (item.label != null)
            Text(
              item.label!,
              maxLines: 1,
              softWrap: false,
              style: context.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          if (item.count != null) ...[
            const SizedBox(width: 6),
            Text(
              '${item.count}',
              style: context.textTheme.labelSmall?.copyWith(
                color: selected ? p.accent : p.faint,
                fontFeatures: tabularFigures,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
    final tappable = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => onChanged(item.value), child: content),
    );
    return item.tooltip == null ? tappable : Tooltip(message: item.tooltip!, child: tappable);
  }
}

// ─────────────────────────────────────────────────────────────── Recherche, filtres, pagination

/// Champ de recherche : icône, bouton d'effacement, anti-rebond optionnel.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.debounce = Duration.zero,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _timer?.cancel();
    if (widget.debounce == Duration.zero) {
      widget.onChanged(value);
    } else {
      _timer = Timer(widget.debounce, () => widget.onChanged(value));
    }
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: _changed,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search_rounded, size: 19),
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(tooltip: 'Effacer', onPressed: _clear, icon: const Icon(Icons.close_rounded, size: 18)),
    ),
  );
}

/// Défilement horizontal (barres de filtres sur mobile) avec fondu sur le bord qui déborde.
class FilterScroller extends StatefulWidget {
  const FilterScroller({super.key, required this.child});

  final Widget child;

  @override
  State<FilterScroller> createState() => _FilterScrollerState();
}

class _FilterScrollerState extends State<FilterScroller> {
  bool _fadeStart = false;
  bool _fadeEnd = false;

  bool _update(ScrollMetrics m) {
    final start = m.pixels > 1;
    final end = m.pixels < m.maxScrollExtent - 1;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (n) => _update(n.metrics),
    child: NotificationListener<ScrollNotification>(
      onNotification: (n) => _update(n.metrics),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          const fade = 28.0;
          final f = rect.width <= 0 ? 0.0 : (fade / rect.width).clamp(0.0, 0.5);
          return LinearGradient(
            colors: [
              _fadeStart ? Colors.transparent : Colors.white,
              Colors.white,
              Colors.white,
              _fadeEnd ? Colors.transparent : Colors.white,
            ],
            stops: [0, f, 1 - f, 1],
          ).createShader(rect);
        },
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: widget.child),
      ),
    ),
  );
}

String _fmtCount(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Pagination : plage affichée, taille de page, numéros (bureau) ou précédent/suivant (mobile).
class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    this.onPageSize,
    this.pageSizes = const [25, 50, 100],
    this.unit = 'résultats',
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;
  final ValueChanged<int>? onPageSize;
  final List<int> pageSizes;
  final String unit;

  int get pageCount => math.max(1, (total / pageSize).ceil());

  /// Numéros visibles ; null = points de suspension.
  List<int?> _pages() {
    final n = pageCount;
    if (n <= 7) return [for (var i = 1; i <= n; i++) i];
    final Set<int> shown;
    if (page <= 4) {
      shown = {1, 2, 3, 4, 5, n};
    } else if (page >= n - 3) {
      shown = {1, n - 4, n - 3, n - 2, n - 1, n};
    } else {
      shown = {1, page - 1, page, page + 1, n};
    }
    final sorted = shown.toList()..sort();
    final out = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.add(null);
      out.add(sorted[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final last = math.min(page * pageSize, total);
    final range = total == 0
        ? 'Aucun résultat'
        : '${_fmtCount(first)}–${_fmtCount(last)} sur ${_fmtCount(total)} $unit';
    final canPrev = page > 1;
    final canNext = page < pageCount;

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) {
          return Row(
            children: [
              _PagerButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Page précédente',
                onTap: canPrev ? () => onPage(page - 1) : null,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $page sur $pageCount',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                    Text(range, style: context.textTheme.bodySmall?.copyWith(fontFeatures: tabularFigures)),
                  ],
                ),
              ),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Page suivante',
                onTap: canNext ? () => onPage(page + 1) : null,
              ),
            ],
          );
        }
        return Row(
          children: [
            Flexible(
              child: Text(
                range,
                style: context.textTheme.bodySmall?.copyWith(fontFeatures: tabularFigures),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onPageSize != null) ...[
              const SizedBox(width: 14),
              PopupMenuButton<int>(
                tooltip: 'Lignes par page',
                initialValue: pageSize,
                onSelected: onPageSize,
                itemBuilder: (context) => [
                  for (final s in pageSizes) PopupMenuItem(value: s, height: 38, child: Text('$s par page')),
                ],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusSm),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pageSize par page', style: context.textTheme.bodySmall?.copyWith(color: p.text)),
                      Icon(Icons.expand_more_rounded, size: 16, color: p.faint),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            _PagerButton(
              icon: Icons.first_page_rounded,
              tooltip: 'Première page',
              onTap: canPrev ? () => onPage(1) : null,
            ),
            _PagerButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Page précédente',
              onTap: canPrev ? () => onPage(page - 1) : null,
            ),
            for (final n in _pages())
              n == null
                  ? SizedBox(
                      width: 26,
                      child: Text('…', textAlign: TextAlign.center, style: context.textTheme.bodySmall),
                    )
                  : _PageNumber(number: n, selected: n == page, onTap: () => onPage(n)),
            _PagerButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Page suivante',
              onTap: canNext ? () => onPage(page + 1) : null,
            ),
            _PagerButton(
              icon: Icons.last_page_rounded,
              tooltip: 'Dernière page',
              onTap: canNext ? () => onPage(pageCount) : null,
            ),
          ],
        );
      },
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    icon: Icon(icon),
  );
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.number, required this.selected, required this.onTap});

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? p.accent.withValues(alpha: context.isDark ? 0.16 : 0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: BorderSide(color: selected ? p.accent.withValues(alpha: 0.35) : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusSm),
          onTap: selected ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$number',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: selected ? p.accent : p.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Graphiques

/// Courbe lissée sans débordement (tangentes horizontales aux points).
Path _smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final mx = (a.dx + b.dx) / 2;
    path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
  }
  return path;
}

/// Mini-courbe de tendance (tuiles KPI).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => CustomPaint(
      size: Size.infinite,
      painter: _SparkPainter(values: values, color: color, t: t),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, required this.t});

  final List<double> values;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max) * 1.1;
    if (maxV <= 0) return;
    final dx = size.width / (values.length - 1);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(i * dx, size.height - 2 - (size.height - 4) * values[i] / maxV * t),
    ];
    final line = _smoothPath(points);
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(points.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.values != values || old.color != color;
}

/// Graphique d'activité : aire lissée (série principale) + ligne d'erreurs, survol interactif.
class AreaChart extends StatefulWidget {
  const AreaChart({
    super.key,
    required this.values,
    this.secondary,
    required this.labels,
    required this.tooltip,
    this.height = 210,
  });

  final List<double> values;
  final List<double>? secondary;

  /// Libellés de l'axe horizontal (chaîne vide = pas de libellé).
  final List<String> labels;
  final List<String> Function(int index) tooltip;
  final double height;

  @override
  State<AreaChart> createState() => _AreaChartState();
}

class _AreaChartState extends State<AreaChart> {
  final _area = GlobalKey();
  int? _hover;

  // Largeur lue au moment du survol (pas de LayoutBuilder : compatible IntrinsicHeight).
  double get _width => (_area.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 0;

  void _pick(Offset local) {
    final n = widget.values.length;
    final width = _width;
    if (n == 0 || width <= 0) return;
    final i = n < 2 ? 0 : (local.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final n = widget.values.length;
    final hover = _hover;
    final width = hover == null ? 0.0 : _width;
    final x = hover == null ? 0.0 : (n < 2 ? width / 2 : hover * width / (n - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: _area,
          height: widget.height,
          child: MouseRegion(
            onHover: (e) => _pick(e.localPosition),
            onExit: (_) => setState(() => _hover = null),
            child: GestureDetector(
              onTapDown: (e) => _pick(e.localPosition),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => CustomPaint(
                        painter: _AreaPainter(
                          values: widget.values,
                          secondary: widget.secondary,
                          t: t,
                          hover: hover,
                          accent: p.accent,
                          accent2: p.iris,
                          danger: p.danger,
                          grid: p.line,
                          surface: p.surface,
                        ),
                      ),
                    ),
                  ),
                  if (hover != null && width > 0)
                    Positioned(
                      top: 0,
                      left: (x + (x > width * 0.6 ? -172 : 14)).clamp(0.0, math.max(0.0, width - 160)),
                      child: IgnorePointer(child: _ChartTooltip(lines: widget.tooltip(hover))),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              Expanded(
                child: Text(
                  widget.labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == widget.labels.length - 1 ? TextAlign.right : TextAlign.center),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: i == _hover ? p.text : p.faint,
                    fontWeight: i == _hover ? FontWeight.w600 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: p.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines.length; i++)
            Text(
              lines[i],
              style: i == 0
                  ? context.textTheme.labelSmall?.copyWith(letterSpacing: 0.2)
                  : context.textTheme.bodySmall?.copyWith(color: p.text, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter({
    required this.values,
    required this.secondary,
    required this.t,
    required this.hover,
    required this.accent,
    required this.accent2,
    required this.danger,
    required this.grid,
    required this.surface,
  });

  final List<double> values;
  final List<double>? secondary;
  final double t;
  final int? hover;
  final Color accent;
  final Color accent2;
  final Color danger;
  final Color grid;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 10.0;
    final h = size.height - top;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + h * i / 3;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), gridPaint);
      }
    }
    final n = values.length;
    if (n == 0) return;
    final all = [...values, ...?secondary];
    final maxV = math.max(1.0, all.reduce(math.max)) * 1.15;
    double xOf(int i) => n < 2 ? size.width / 2 : i * size.width / (n - 1);
    List<Offset> pts(List<double> vs) => [
      for (var i = 0; i < vs.length; i++) Offset(xOf(i), top + h - h * vs[i] / maxV * t),
    ];

    final main = pts(values);
    final rect = Offset.zero & size;
    if (n >= 2) {
      final line = _smoothPath(main);
      final fill = Path.from(line)
        ..lineTo(main.last.dx, size.height)
        ..lineTo(main.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.0)],
          ).createShader(rect),
      );
      canvas.drawPath(
        line,
        Paint()
          ..shader = LinearGradient(colors: [accent, accent2]).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
      final sec = secondary;
      if (sec != null && sec.any((v) => v > 0)) {
        canvas.drawPath(
          _smoothPath(pts(sec)),
          Paint()
            ..color = danger.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    final hi = hover;
    if (hi != null && hi < n) {
      final x = xOf(hi);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, size.height),
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(main[hi], 6, Paint()..color = surface);
      canvas.drawCircle(
        main[hi],
        6,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else if (n >= 1) {
      canvas.drawCircle(main.last, 4, Paint()..color = accent2);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.t != t || old.hover != hover || old.values != values || old.secondary != secondary || old.accent != accent;
}
