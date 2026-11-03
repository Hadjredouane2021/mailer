import 'dart:async';

import 'package:flutter/material.dart';
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

/// Suivi en direct d'un envoi : progression, cadence, journal, contrôles.
class SendConsolePage extends StatefulWidget {
  const SendConsolePage({super.key, required this.jobId});

  final String jobId;

  @override
  State<SendConsolePage> createState() => _SendConsolePageState();
}

class _SendConsolePageState extends State<SendConsolePage> {
  late final Api _api = context.read<Session>().api;
  Job? _job;
  final List<JobLog> _logs = [];
  Object? _error;
  Timer? _timer;
  bool _polling = false;
  bool _busy = false;
  bool _errorsOnly = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final detail = await _api.job(widget.jobId, since: _logs.length);
      if (!mounted) return;
      setState(() {
        _job = detail.job;
        _logs.addAll(detail.log);
        _error = null;
      });
      // Envoi terminé et journal complet : plus besoin d'interroger le serveur.
      if (!detail.job.status.isLive && detail.log.isEmpty && _logs.length >= detail.job.logCount) {
        _timer?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _polling = false;
    }
  }

  Future<void> _control(String action) async {
    if (action == 'cancel') {
      final ok = await confirmAction(
        context,
        title: 'Arrêter l’envoi ?',
        message:
            'L’e-mail en cours se termine puis l’envoi s’arrête. '
            'Les destinataires restants gardent sent=0 : vous pourrez relancer plus tard.',
        confirmLabel: 'Arrêter',
        destructive: true,
        icon: Icons.stop_circle_outlined,
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await _api.control(widget.jobId, action);
      await _poll();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _relaunch(Job job) async {
    try {
      final campaign = await _api.campaign(job.campaignId);
      if (mounted) await launchCampaign(context, campaign);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    if (job == null) {
      return PageScaffold(
        child: _error == null
            ? const PageSkeleton()
            : EmptyState(
                icon: Icons.cloud_off_rounded,
                tone: Tone.danger,
                title: 'Envoi introuvable',
                message: '$_error',
                action: OutlinedButton(onPressed: () => context.go('/history'), child: const Text('Historique')),
              ),
      );
    }
    final canEdit = context.watch<Session>().canEdit;
    return PageScaffold(
      maxWidth: 1440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Console d’envoi',
            title: job.campaignName,
            subtitle: [
              'Table ${job.table}',
              '« ${job.subject} »',
              if (job.startedBy != null) 'lancé par ${job.startedBy}',
            ].join(' · '),
            leading: IconButton.outlined(
              tooltip: 'Retour',
              style: IconButton.styleFrom(side: BorderSide(color: context.palette.line)),
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            actions: canEdit ? _actions(job) : const [],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InfoBanner(
                tone: Tone.warning,
                icon: Icons.wifi_off_rounded,
                text: 'Connexion perdue avec l’API, nouvelle tentative… ($_error)',
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final summary = Column(
                children: [_progressPanel(context, job), const SizedBox(height: 16), _cadencePanel(context, job)],
              );
              final log = _logPanel(context, job);
              if (c.maxWidth < 980) return Column(children: [summary, const SizedBox(height: 16), log]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 390, child: summary),
                  const SizedBox(width: 16),
                  Expanded(child: log),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(Job job) {
    final p = context.palette;
    if (job.status.isLive) {
      return [
        if (job.status == JobStatus.waiting)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _control('skip'),
            icon: const Icon(Icons.fast_forward_rounded, size: 18),
            label: const Text('Lot suivant maintenant'),
          ),
        if (job.status == JobStatus.paused)
          GradientButton(
            label: 'Reprendre',
            icon: Icons.play_arrow_rounded,
            onPressed: _busy ? null : () => _control('resume'),
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _control('pause'),
            icon: const Icon(Icons.pause_rounded, size: 19),
            label: const Text('Pause'),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: p.danger,
            side: BorderSide(color: p.danger.withValues(alpha: 0.35)),
          ),
          onPressed: _busy ? null : () => _control('cancel'),
          icon: const Icon(Icons.stop_rounded, size: 19),
          label: const Text('Arrêter'),
        ),
      ];
    }
    return [
      OutlinedButton.icon(
        onPressed: () => context.go('/recipients?table=${job.table}'),
        icon: const Icon(Icons.people_alt_outlined, size: 18),
        label: const Text('Destinataires'),
      ),
      if (job.remaining > 0)
        GradientButton(
          label: 'Relancer (${fmtInt(job.remaining)} restants)',
          icon: Icons.replay_rounded,
          onPressed: () => _relaunch(job),
        )
      else
        FilledButton.icon(
          onPressed: () => context.go('/campaigns/${job.campaignId}'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ouvrir la campagne'),
        ),
    ];
  }

  Widget _progressPanel(BuildContext context, Job job) {
    final tone = jobTone(job.status);
    final p = context.palette;
    return Panel(
      glow: job.status.isLive ? tone.of(context) : null,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        children: [
          Row(
            children: [
              StatusPill(job.status.label, tone: tone, pulse: job.status.isLive),
              const Spacer(),
              Text('Lot ${job.batch}', style: context.textTheme.labelLarge?.copyWith(color: p.muted)),
            ],
          ),
          const SizedBox(height: 22),
          ProgressRing(
            value: job.progress,
            size: 208,
            stroke: 16,
            tone: job.status == JobStatus.failed
                ? Tone.danger
                : (job.status == JobStatus.completed ? Tone.success : Tone.accent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(job.progress * 100).toStringAsFixed(job.progress >= 1 || job.progress == 0 ? 0 : 1)} %',
                  style: context.textTheme.displaySmall?.copyWith(fontSize: 40, fontFeatures: tabularFigures),
                ),
                Text('${fmtInt(job.processed)} / ${fmtInt(job.pendingAtStart)}', style: context.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: p.surfaceHigh,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Stat(
                    label: 'Envoyés',
                    value: fmtInt(job.sent),
                    tone: Tone.success,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Container(width: 1, height: 34, color: p.line),
                Expanded(
                  child: Stat(
                    label: 'Erreurs',
                    value: fmtInt(job.failed),
                    tone: job.failed > 0 ? Tone.danger : null,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Container(width: 1, height: 34, color: p.line),
                Expanded(
                  child: Stat(label: 'Restants', value: fmtInt(job.remaining), align: CrossAxisAlignment.center),
                ),
              ],
            ),
          ),
          if (job.error != null) ...[
            const SizedBox(height: 16),
            InfoBanner(tone: Tone.danger, icon: Icons.error_outline_rounded, text: job.error!),
          ] else if (job.status == JobStatus.completed) ...[
            const SizedBox(height: 16),
            InfoBanner(
              tone: Tone.success,
              icon: Icons.verified_outlined,
              text: job.failed == 0
                  ? 'Envoi terminé : ${fmtInt(job.sent)} e-mails envoyés.'
                  : 'Envoi terminé : ${fmtInt(job.sent)} envoyés, ${fmtInt(job.failed)} en erreur (restés à sent=0).',
            ),
          ],
        ],
      ),
    );
  }

  Widget _cadencePanel(BuildContext context, Job job) {
    final p = context.palette;
    final waiting = job.status == JobStatus.waiting && job.nextBatchAt != null;
    final left = waiting ? job.nextBatchAt!.difference(DateTime.now()) : Duration.zero;
    final pauseProgress = waiting && job.pauseSeconds > 0 ? 1 - left.inMilliseconds / (job.pauseSeconds * 1000) : 0.0;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Cadence', icon: Icons.speed_rounded),
          if (waiting) ...[
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: p.iris, size: 19),
                const SizedBox(width: 8),
                Text('Prochain lot dans', style: context.textTheme.bodyMedium),
                const Spacer(),
                CountdownText(
                  target: job.nextBatchAt!,
                  style: context.textTheme.titleLarge?.copyWith(color: p.iris),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Meter(value: pauseProgress, tone: Tone.iris, height: 6),
            const SizedBox(height: 16),
          ],
          _kv(context, 'E-mails par lot', fmtInt(job.batchSize)),
          _kv(context, 'Pause entre lots', '${job.pauseSeconds} s'),
          _kv(context, 'Démarré', fmtDateTime(job.createdAt)),
          if (job.startedBy != null) _kv(context, 'Lancé par', job.startedBy!),
          _kv(
            context,
            job.finishedAt == null ? 'Durée' : 'Terminé',
            job.finishedAt == null ? fmtDuration(job.duration) : fmtDateTime(job.finishedAt),
          ),
          if (job.finishedAt != null) _kv(context, 'Durée', fmtDuration(job.duration)),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.palette.line.withValues(alpha: 0.6))),
    ),
    child: Row(
      children: [
        Text(k, style: context.textTheme.bodySmall),
        const Spacer(),
        Text(v, style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _logPanel(BuildContext context, Job job) {
    final p = context.palette;
    final errors = _logs.where((l) => !l.ok).length;
    final entries = (_errorsOnly ? _logs.where((l) => !l.ok) : _logs).toList().reversed.toList();
    return Panel(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionTitle(
              'Journal d’envoi',
              subtitle: '${fmtInt(_logs.length)} entrée(s) · le plus récent en haut',
              icon: Icons.receipt_long_outlined,
              trailing: PillTabs<bool>(
                value: _errorsOnly,
                items: [
                  PillTab(false, label: 'Tous', count: _logs.length),
                  PillTab(true, label: 'Erreurs', count: errors),
                ],
                onChanged: (v) => setState(() => _errorsOnly = v),
              ),
            ),
          ),
          Divider(height: 1, color: p.line),
          Container(
            height: 640,
            color: p.code,
            child: entries.isEmpty
                ? EmptyState(
                    icon: _errorsOnly ? Icons.verified_outlined : Icons.outbox_outlined,
                    tone: _errorsOnly ? Tone.success : Tone.accent,
                    title: _errorsOnly ? 'Aucune erreur' : 'En attente du premier e-mail…',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _LogRow(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final JobLog entry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = entry.ok ? p.success : p.danger;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: entry.ok ? null : p.danger.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: p.line.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          if (!compact)
            SizedBox(
              width: 70,
              child: Text(fmtTime(entry.at), style: monoStyle(size: 11.5, color: p.faint)),
            ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(entry.ok ? Icons.check_rounded : Icons.close_rounded, size: 12, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              entry.email.isEmpty ? '(adresse vide)' : entry.email,
              style: monoStyle(size: 12.5, color: p.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Tooltip(
              message: entry.message,
              child: Text(
                entry.message,
                style: context.textTheme.bodySmall?.copyWith(color: entry.ok ? p.muted : p.danger),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Text('lot ${entry.batch}', style: monoStyle(size: 11, color: p.faint)),
          ],
        ],
      ),
    );
  }
}
