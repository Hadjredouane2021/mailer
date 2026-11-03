import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Tone jobTone(JobStatus s) => switch (s) {
  JobStatus.running => Tone.info,
  JobStatus.waiting => Tone.iris,
  JobStatus.paused => Tone.warning,
  JobStatus.completed => Tone.success,
  JobStatus.cancelled => Tone.neutral,
  JobStatus.failed => Tone.danger,
};

Tone campaignTone(CampaignStatus s) => switch (s) {
  CampaignStatus.active => Tone.success,
  CampaignStatus.draft => Tone.warning,
  CampaignStatus.archived => Tone.neutral,
};

Tone roleTone(Role r) => switch (r) {
  Role.admin => Tone.wine,
  Role.editor => Tone.accent,
  Role.viewer => Tone.neutral,
};

IconData roleIcon(Role r) => switch (r) {
  Role.admin => Icons.shield_outlined,
  Role.editor => Icons.edit_outlined,
  Role.viewer => Icons.visibility_outlined,
};

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});

  final Role role;

  @override
  Widget build(BuildContext context) => StatusPill(role.label, tone: roleTone(role), icon: roleIcon(role));
}

/// Bandeau « lecture seule » pour les comptes Lecteur.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key, this.text = 'Lecture seule : votre rôle « Lecteur » ne permet pas de modifier.'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InfoBanner(tone: Tone.neutral, icon: Icons.visibility_outlined, text: text),
  );
}

/// Confirmation détaillée puis lancement de l'envoi par lots (côté serveur).
Future<void> launchCampaign(BuildContext context, Campaign campaign, {TableCounts? counts}) async {
  final api = context.read<Session>().api;
  final router = GoRouter.of(context);
  final ok = await confirmAction(
    context,
    title: 'Lancer l’envoi ?',
    message:
        'Les e-mails partent par lots, avec une pause entre chaque lot. '
        'Vous pourrez mettre en pause ou arrêter à tout moment.',
    confirmLabel: 'Lancer l’envoi',
    icon: Icons.rocket_launch_outlined,
    details: DetailRows([
      ('Campagne', campaign.name),
      ('Table', counts == null ? campaign.table : '${campaign.table} · ${fmtInt(counts.pending)} en attente'),
      ('Expéditeur', '${campaign.fromName} <${campaign.fromEmail}>'),
      ('Objet', campaign.subject),
      ('Cadence', '${campaign.batchSize} e-mails / lot · pause ${campaign.pauseSeconds} s'),
    ]),
  );
  if (!ok || !context.mounted) return;
  try {
    final job = await api.run(campaign.id);
    router.go('/jobs/${job.id}');
  } catch (e) {
    if (context.mounted) showToast(context, '$e', error: true);
  }
}

/// Compte à rebours mis à jour chaque seconde (pause entre deux lots).
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.target, this.style, this.prefix = ''});

  final DateTime target;
  final TextStyle? style;
  final String prefix;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '${widget.prefix}${fmtCountdown(widget.target.difference(DateTime.now()))}',
    style: (widget.style ?? const TextStyle()).copyWith(fontFeatures: tabularFigures),
  );
}

/// Ligne d'historique d'envoi (tableau de bord + page Historique).
class JobTile extends StatefulWidget {
  const JobTile({super.key, required this.job, this.dense = false});

  final Job job;
  final bool dense;

  @override
  State<JobTile> createState() => _JobTileState();
}

class _JobTileState extends State<JobTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final job = widget.job;
    final tone = jobTone(job.status);
    final wide = !widget.dense && MediaQuery.sizeOf(context).width >= 760;
    final meta = [job.table, fmtRelative(job.createdAt), if (job.startedBy != null) 'par ${job.startedBy}'].join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/jobs/${job.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 10 : 13),
          decoration: BoxDecoration(
            color: _hover ? p.text.withValues(alpha: 0.035) : Colors.transparent,
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ProgressRing(value: job.progress, size: 42, stroke: 4, tone: tone),
                    Text(
                      '${(job.progress * 100).round()}',
                      style: context.textTheme.labelSmall?.copyWith(color: p.text, letterSpacing: 0, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.campaignName,
                      style: context.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: context.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (wide) ...[
                _Count(icon: Icons.check_rounded, value: job.sent, color: p.success),
                const SizedBox(width: 16),
                _Count(icon: Icons.close_rounded, value: job.failed, color: job.failed > 0 ? p.danger : p.faint),
                const SizedBox(width: 16),
                SizedBox(
                  width: 72,
                  child: Text(
                    fmtDuration(job.duration),
                    textAlign: TextAlign.right,
                    style: context.textTheme.bodySmall?.copyWith(fontFeatures: tabularFigures),
                  ),
                ),
                const SizedBox(width: 18),
              ],
              StatusPill(job.status.label, tone: tone, pulse: job.status.isLive),
              if (wide) ...[
                const SizedBox(width: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hover ? 1 : 0,
                  child: Icon(Icons.chevron_right_rounded, color: p.faint, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.color});

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 4),
      Text(fmtInt(value), style: context.textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────── Mots de passe

/// Score 0–4 : longueur, casse, chiffres, symboles.
int passwordScore(String pw) {
  if (pw.length < 8) return 0;
  var score = 1;
  if (pw.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(pw) && RegExp(r'[A-Z]').hasMatch(pw)) score++;
  if (RegExp(r'\d').hasMatch(pw) && RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
  return score;
}

/// Mot de passe aléatoire lisible (sans caractères ambigus).
String generatePassword([int length = 16]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789-_!@#%';
  final random = math.Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

/// Champ mot de passe : afficher/masquer, jauge de robustesse, génération optionnelle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint,
    this.showStrength = false,
    this.allowGenerate = false,
    this.autofillHints,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final bool showStrength;
  final bool allowGenerate;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (widget.showStrength && mounted) setState(() {});
  }

  void _generate() {
    widget.controller.text = generatePassword();
    setState(() => _obscure = false);
    Clipboard.setData(ClipboardData(text: widget.controller.text));
    showToast(context, 'Mot de passe généré et copié dans le presse-papiers.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final score = passwordScore(widget.controller.text);
    const labels = ['Trop court', 'Faible', 'Moyen', 'Bon', 'Excellent'];
    final colors = [p.danger, p.danger, p.warning, p.success, p.success];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.allowGenerate)
                  IconButton(
                    tooltip: 'Générer un mot de passe',
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  ),
                IconButton(
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        if (widget.showStrength && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < math.max(1, score) ? colors[score] : p.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text(
                  labels[score],
                  textAlign: TextAlign.right,
                  style: context.textTheme.bodySmall?.copyWith(color: colors[score], fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
