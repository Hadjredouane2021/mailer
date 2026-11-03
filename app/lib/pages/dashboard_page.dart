import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 5 || h >= 18 ? 'Bonsoir' : 'Bonjour';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final api = session.api;
    final name = session.user?.firstName ?? '';
    return PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: fmtToday(),
            title: name.isEmpty ? _greeting() : '${_greeting()}, $name',
            subtitle: 'Voici l’état de la base « mail » et de vos envois.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Historique'),
              ),
              if (session.canEdit)
                GradientButton(
                  label: 'Nouvelle campagne',
                  icon: Icons.add_rounded,
                  onPressed: () => context.go('/campaigns/new'),
                ),
            ],
          ),
          Loader<DashboardStats>(
            load: api.stats,
            refreshEvery: const Duration(seconds: 5),
            builder: (context, s, _) => _Bento(stats: s),
          ),
        ],
      ),
    );
  }
}

class _Bento extends StatelessWidget {
  const _Bento({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final sentTrend = [for (final d in s.daily) d.sent.toDouble()];
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        Widget pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => wide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: flexA, child: a),
                    const SizedBox(width: gap),
                    Expanded(flex: flexB, child: b),
                  ],
                ),
              )
            : Column(
                children: [
                  a,
                  const SizedBox(height: gap),
                  b,
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final job in s.activeJobs) ...[FadeIn(child: _LiveJob(job: job)), const SizedBox(height: gap)],
            FadeIn(
              delay: const Duration(milliseconds: 60),
              child: ResponsiveGrid(
                minItemWidth: 160,
                children: [
                  KpiTile(
                    label: 'Destinataires',
                    value: fmtInt(s.totals.total),
                    caption: '${s.tables.length} table${s.tables.length > 1 ? 's' : ''} dans « mail »',
                    icon: Icons.people_alt_outlined,
                    tone: Tone.iris,
                    onTap: () => context.go('/recipients'),
                  ),
                  KpiTile(
                    label: 'Envoyés · 14 jours',
                    value: fmtInt(s.daily.fold<int>(0, (a, d) => a + d.sent)),
                    caption: '${fmtInt(s.totals.sent)} marqués envoyés au total',
                    icon: Icons.north_east_rounded,
                    tone: Tone.accent,
                    trend: sentTrend,
                  ),
                  KpiTile(
                    label: 'En attente',
                    value: fmtInt(s.totals.pending),
                    caption: 'prêts pour un prochain envoi',
                    icon: Icons.schedule_send_outlined,
                    tone: Tone.warning,
                    progress: s.totals.total == 0 ? 0 : s.totals.pending / s.totals.total,
                  ),
                  KpiTile(
                    label: 'Campagnes',
                    value: fmtInt(s.campaignsTotal),
                    caption: '${s.campaignsActive} active${s.campaignsActive > 1 ? 's' : ''}',
                    icon: Icons.campaign_outlined,
                    tone: Tone.success,
                    onTap: () => context.go('/campaigns'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: gap),
            FadeIn(
              delay: const Duration(milliseconds: 120),
              child: pair(_ActivityPanel(daily: s.daily), _CoveragePanel(totals: s.totals), flexA: 2),
            ),
            const SizedBox(height: gap),
            FadeIn(
              delay: const Duration(milliseconds: 180),
              child: pair(_RecentJobs(jobs: s.recentJobs), _TablesPanel(tables: s.tables)),
            ),
          ],
        );
      },
    );
  }
}

class _LiveJob extends StatelessWidget {
  const _LiveJob({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = jobTone(job.status);
    return Panel(
      glow: tone.of(context),
      onTap: () => context.go('/jobs/${job.id}'),
      child: Wrap(
        spacing: 22,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(
                value: job.progress,
                size: 76,
                stroke: 8,
                tone: tone,
                child: Text('${(job.progress * 100).round()} %', style: context.textTheme.titleSmall),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusPill(job.status.label, tone: tone, pulse: true),
                    const SizedBox(height: 8),
                    Text(job.campaignName, style: context.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Lot ${job.batch} · ${fmtInt(job.sent)} envoyés · ${fmtInt(job.failed)} erreurs · ${fmtInt(job.remaining)} restants',
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (job.status == JobStatus.waiting && job.nextBatchAt != null) ...[
                Icon(Icons.timer_outlined, color: p.iris, size: 19),
                const SizedBox(width: 6),
                CountdownText(
                  target: job.nextBatchAt!,
                  prefix: 'Prochain lot dans ',
                  style: context.textTheme.labelLarge?.copyWith(color: p.iris),
                ),
                const SizedBox(width: 18),
              ],
              FilledButton.icon(
                onPressed: () => context.go('/jobs/${job.id}'),
                icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                label: const Text('Console d’envoi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.daily});

  final List<DailyPoint> daily;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = daily.fold<int>(0, (a, d) => a + d.sent);
    final failed = daily.fold<int>(0, (a, d) => a + d.failed);
    final rate = total + failed == 0 ? null : total / (total + failed);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Activité d’envoi',
            subtitle: '14 derniers jours',
            trailing: Wrap(
              spacing: 14,
              children: [
                _Legend(color: p.accent, label: 'Envoyés'),
                _Legend(color: p.danger, label: 'Erreurs'),
              ],
            ),
          ),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtInt(total),
                    style: context.textTheme.displaySmall?.copyWith(fontSize: 40, fontFeatures: tabularFigures),
                  ),
                  Text('e-mails envoyés', style: context.textTheme.bodySmall),
                ],
              ),
              if (rate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: StatusPill(
                    '${fmtPercent(rate)} de réussite',
                    tone: rate >= 0.98 ? Tone.success : (rate >= 0.9 ? Tone.warning : Tone.danger),
                    icon: Icons.verified_outlined,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          AreaChart(
            values: [for (final d in daily) d.sent.toDouble()],
            secondary: [for (final d in daily) d.failed.toDouble()],
            labels: [
              for (var i = 0; i < daily.length; i++)
                i == daily.length - 1 ? 'Auj.' : (i % 3 == 0 ? fmtDayShort(daily[i].date) : ''),
            ],
            tooltip: (i) => [
              fmtDayShort(daily[i].date).toUpperCase(),
              '${fmtInt(daily[i].sent)} envoyés',
              '${fmtInt(daily[i].failed)} erreurs',
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.textTheme.bodySmall),
    ],
  );
}

/// Part de la base déjà servie (colonne sent).
class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.totals});

  final TableCounts totals;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Couverture de la base', subtitle: 'Destinataires marqués envoyés'),
          const SizedBox(height: 4),
          Center(
            child: ProgressRing(
              value: totals.progress,
              size: 184,
              stroke: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtPercent(totals.progress),
                    style: context.textTheme.headlineMedium?.copyWith(fontFeatures: tabularFigures, fontSize: 32),
                  ),
                  Text('de la base', style: context.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceHigh,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Stat(label: 'Envoyés', value: fmtInt(totals.sent), tone: Tone.success),
                ),
                Container(width: 1, height: 36, color: p.line),
                const SizedBox(width: 16),
                Expanded(
                  child: Stat(label: 'En attente', value: fmtInt(totals.pending), tone: Tone.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentJobs extends StatelessWidget {
  const _RecentJobs({required this.jobs});

  final List<Job> jobs;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SectionTitle(
            'Derniers envois',
            trailing: TextButton(onPressed: () => context.go('/history'), child: const Text('Tout voir')),
          ),
        ),
        if (jobs.isEmpty)
          const EmptyState(
            icon: Icons.outbox_outlined,
            title: 'Aucun envoi pour l’instant',
            message: 'Lancez une campagne : sa progression apparaîtra ici.',
          )
        else
          for (final job in jobs.take(5)) JobTile(job: job, dense: true),
      ],
    ),
  );
}

class _TablesPanel extends StatelessWidget {
  const _TablesPanel({required this.tables});

  final List<TableInfo> tables;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tables]..sort((a, b) => b.total.compareTo(a.total));
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SectionTitle(
              'Tables de destinataires',
              trailing: TextButton(onPressed: () => context.go('/recipients'), child: const Text('Gérer')),
            ),
          ),
          if (sorted.isEmpty)
            const EmptyState(
              icon: Icons.table_rows_outlined,
              title: 'Aucune table',
              message: 'Une table doit contenir les colonnes email et sent.',
            )
          else
            for (final t in sorted.take(6)) _TableRow(table: t),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.table});

  final TableInfo table;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = table.total > 0 && table.pending == 0;
    final tone = done ? Tone.success : Tone.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(radiusMd),
      onTap: () => context.go('/recipients?table=${table.name}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.name,
                    style: monoStyle(size: 13, weight: FontWeight.w600, color: p.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (table.busy) ...[const StatusPill('Envoi', tone: Tone.info, pulse: true), const SizedBox(width: 10)],
                Text(
                  '${fmtInt(table.sent)} / ${fmtInt(table.total)}',
                  style: context.textTheme.bodySmall?.copyWith(fontFeatures: tabularFigures),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  child: Text(
                    fmtPercent(table.progress),
                    textAlign: TextAlign.right,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: tone.of(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Meter(value: table.progress, tone: tone, height: 5),
          ],
        ),
      ),
    );
  }
}
