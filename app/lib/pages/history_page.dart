import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

enum _Filter { all, live, completed, problems }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  _Filter _filter = _Filter.all;
  int _page = 1;
  int _pageSize = 20;

  static bool _match(Job j, _Filter filter) => switch (filter) {
    _Filter.all => true,
    _Filter.live => j.status.isLive,
    _Filter.completed => j.status == JobStatus.completed,
    _Filter.problems => j.status == JobStatus.failed || j.status == JobStatus.cancelled || j.failed > 0,
  };

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return PageScaffold(
      maxWidth: 1200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            eyebrow: 'Envois',
            title: 'Historique',
            subtitle: 'Chaque lancement de campagne, sa progression et son journal détaillé.',
          ),
          Loader<List<Job>>(
            load: () => api.jobs(limit: 200),
            refreshEvery: const Duration(seconds: 5),
            builder: (context, jobs, _) {
              if (jobs.isEmpty) {
                return const Panel(
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Aucun envoi pour l’instant',
                    message: 'Les envois lancés depuis Mailler Studio apparaîtront ici avec leur journal.',
                  ),
                );
              }
              final sent = jobs.fold<int>(0, (a, j) => a + j.sent);
              final failed = jobs.fold<int>(0, (a, j) => a + j.failed);
              final visible = jobs.where((j) => _match(j, _filter)).toList();
              final pageCount = visible.isEmpty ? 1 : (visible.length / _pageSize).ceil();
              final page = _page.clamp(1, pageCount);
              final shown = visible.skip((page - 1) * _pageSize).take(_pageSize).toList();
              int count(_Filter f) => jobs.where((j) => _match(j, f)).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveGrid(
                    minItemWidth: 160,
                    children: [
                      KpiTile(
                        label: 'Envois',
                        value: fmtInt(jobs.length),
                        caption: '${count(_Filter.live)} en cours',
                        icon: Icons.rocket_launch_outlined,
                        tone: Tone.iris,
                      ),
                      KpiTile(
                        label: 'E-mails envoyés',
                        value: fmtInt(sent),
                        caption: 'sur l’ensemble des envois',
                        icon: Icons.mark_email_read_outlined,
                        tone: Tone.success,
                        progress: sent + failed == 0 ? 0 : sent / (sent + failed),
                      ),
                      KpiTile(
                        label: 'Erreurs',
                        value: fmtInt(failed),
                        caption: sent + failed == 0
                            ? 'aucune tentative'
                            : '${fmtPercent(failed / (sent + failed))} des tentatives',
                        icon: Icons.report_gmailerrorred_outlined,
                        tone: failed > 0 ? Tone.danger : Tone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilterScroller(
                    child: PillTabs<_Filter>(
                      value: _filter,
                      items: [
                        PillTab(_Filter.all, label: 'Tous', count: jobs.length),
                        PillTab(_Filter.live, label: 'En cours', count: count(_Filter.live)),
                        PillTab(_Filter.completed, label: 'Terminés', count: count(_Filter.completed)),
                        PillTab(_Filter.problems, label: 'À vérifier', count: count(_Filter.problems)),
                      ],
                      onChanged: (f) => setState(() {
                        _filter = f;
                        _page = 1;
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: visible.isEmpty
                        ? const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'Aucun envoi dans ce filtre')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(children: [for (final job in shown) JobTile(job: job)]),
                              ),
                              if (visible.length > 10)
                                Container(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: context.palette.line)),
                                  ),
                                  child: Pager(
                                    page: page,
                                    pageSize: _pageSize,
                                    total: visible.length,
                                    unit: 'envois',
                                    pageSizes: const [10, 20, 50],
                                    onPage: (n) => setState(() => _page = n),
                                    onPageSize: (n) => setState(() {
                                      _pageSize = n;
                                      _page = 1;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
