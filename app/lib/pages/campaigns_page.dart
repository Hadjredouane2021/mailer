import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'shell.dart';

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  CampaignStatus? _filter;
  String _query = '';
  Key _loaderKey = UniqueKey();
  final _search = TextEditingController();

  void _reload() => setState(() => _loaderKey = UniqueKey());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final compact = MediaQuery.sizeOf(context).width < 720;
    return PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Envois',
            title: 'Campagnes',
            subtitle: 'Modèles d’e-mails, expéditeur, table cible et cadence d’envoi.',
            actions: [
              if (session.canEdit)
                GradientButton(
                  label: 'Nouvelle campagne',
                  icon: Icons.add_rounded,
                  onPressed: () => context.go('/campaigns/new'),
                ),
            ],
          ),
          Loader<List<Campaign>>(
            key: _loaderKey,
            load: session.api.campaigns,
            refreshEvery: const Duration(seconds: 15),
            builder: (context, campaigns, reload) {
              final counts = {for (final s in CampaignStatus.values) s: campaigns.where((c) => c.status == s).length};
              final visible = campaigns.where((c) {
                if (_filter != null && c.status != _filter) return false;
                if (_query.isEmpty) return true;
                return '${c.name} ${c.subject} ${c.table} ${c.description}'.toLowerCase().contains(_query);
              }).toList()..sort((a, b) => _order(a).compareTo(_order(b)));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: compact ? double.infinity : 320,
                        child: SearchField(
                          controller: _search,
                          hint: 'Rechercher une campagne, un objet…',
                          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      FilterScroller(
                        child: PillTabs<CampaignStatus?>(
                          value: _filter,
                          items: [
                            PillTab(null, label: 'Toutes', count: campaigns.length),
                            for (final s in CampaignStatus.values) PillTab(s, label: '${s.label}s', count: counts[s]),
                          ],
                          onChanged: (s) => setState(() => _filter = s),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (visible.isEmpty)
                    Panel(
                      child: EmptyState(
                        icon: Icons.campaign_outlined,
                        title: campaigns.isEmpty ? 'Aucune campagne' : 'Aucun résultat',
                        message: campaigns.isEmpty
                            ? 'Créez votre première campagne : objet, contenu HTML et table de destinataires.'
                            : 'Modifiez la recherche ou le filtre.',
                        action: campaigns.isEmpty && session.canEdit
                            ? GradientButton(
                                label: 'Créer une campagne',
                                icon: Icons.add_rounded,
                                onPressed: () => context.go('/campaigns/new'),
                              )
                            : null,
                      ),
                    )
                  else
                    ResponsiveGrid(
                      minItemWidth: 340,
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          FadeIn(
                            delay: Duration(milliseconds: 30 * (i < 12 ? i : 12)),
                            child: _CampaignCard(campaign: visible[i], onChanged: _reload, canEdit: session.canEdit),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Actives d'abord, puis brouillons, puis archivées ; les plus récentes en tête.
  static String _order(Campaign c) {
    final rank = switch (c.status) {
      CampaignStatus.active => 0,
      CampaignStatus.draft => 1,
      CampaignStatus.archived => 2,
    };
    final ts = 9999999999999 - (c.updatedAt?.millisecondsSinceEpoch ?? 0);
    return '$rank-$ts';
  }
}

enum _Menu { duplicate, activate, archive, delete }

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, required this.onChanged, required this.canEdit});

  final Campaign campaign;
  final VoidCallback onChanged;
  final bool canEdit;

  Future<void> _onMenu(BuildContext context, _Menu action) async {
    final api = context.read<Session>().api;
    try {
      switch (action) {
        case _Menu.duplicate:
          final copy = await api.duplicateCampaign(campaign.id);
          if (context.mounted) context.go('/campaigns/${copy.id}');
        case _Menu.activate:
          await api.updateCampaign(campaign.id, {'status': 'active'});
          onChanged();
        case _Menu.archive:
          await api.updateCampaign(campaign.id, {'status': 'archived'});
          onChanged();
        case _Menu.delete:
          final ok = await confirmAction(
            context,
            title: 'Supprimer la campagne ?',
            message: '« ${campaign.name} » sera supprimée. Les destinataires et l’historique ne sont pas touchés.',
            confirmLabel: 'Supprimer',
            destructive: true,
          );
          if (!ok) return;
          await api.deleteCampaign(campaign.id);
          onChanged();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = campaign.tableStats;
    final live = campaign.activeJobId != null;
    final done = stats != null && stats.total > 0 && stats.pending == 0;

    Widget action;
    if (live) {
      action = FilledButton.icon(
        onPressed: () => context.go('/jobs/${campaign.activeJobId}'),
        icon: const Icon(Icons.monitor_heart_outlined, size: 17),
        label: const Text('Suivre'),
      );
    } else if (done) {
      action = Tooltip(
        message: 'Tous les destinataires de « ${campaign.table} » ont sent=1',
        child: const StatusPill('Tout envoyé', tone: Tone.success, icon: Icons.done_all_rounded),
      );
    } else if (canEdit) {
      action = GradientButton(
        label: 'Envoyer',
        icon: Icons.send_rounded,
        compact: true,
        onPressed: stats == null ? null : () => launchCampaign(context, campaign, counts: stats),
      );
    } else {
      action = const SizedBox.shrink();
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 18),
      glow: live ? p.info : null,
      onTap: () => context.go('/campaigns/${campaign.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              live
                  ? const StatusPill('Envoi en cours', tone: Tone.info, pulse: true)
                  : StatusPill(campaign.status.label, tone: campaignTone(campaign.status)),
              const Spacer(),
              if (canEdit)
                PopupMenuButton<_Menu>(
                  tooltip: 'Actions',
                  icon: Icon(Icons.more_horiz_rounded, color: p.muted),
                  onSelected: (a) => _onMenu(context, a),
                  itemBuilder: (context) => [
                    _item(context, _Menu.duplicate, Icons.copy_rounded, 'Dupliquer'),
                    if (campaign.status != CampaignStatus.active)
                      _item(context, _Menu.activate, Icons.play_circle_outline_rounded, 'Marquer active'),
                    if (campaign.status != CampaignStatus.archived)
                      _item(context, _Menu.archive, Icons.inventory_2_outlined, 'Archiver'),
                    const PopupMenuDivider(),
                    _item(context, _Menu.delete, Icons.delete_outline_rounded, 'Supprimer', danger: true),
                  ],
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(campaign.name, style: context.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: Text(
                    campaign.description.isEmpty ? 'Aucune description' : campaign.description,
                    style: context.textTheme.bodySmall?.copyWith(color: campaign.description.isEmpty ? p.faint : null),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, size: 16, color: p.faint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          campaign.subject,
                          style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(icon: Icons.table_rows_outlined, label: campaign.table, mono: true),
                    _Chip(icon: Icons.layers_outlined, label: '${campaign.batchSize} / lot'),
                    _Chip(icon: Icons.timer_outlined, label: '${campaign.pauseSeconds} s'),
                    if (campaign.source != null) _Chip(icon: Icons.code_rounded, label: campaign.source!, mono: true),
                  ],
                ),
                const SizedBox(height: 18),
                if (stats != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${fmtInt(stats.sent)} / ${fmtInt(stats.total)} envoyés',
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmtPercent(stats.progress),
                        style: context.textTheme.labelMedium?.copyWith(
                          color: done ? p.success : p.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Meter(value: stats.progress, tone: done ? Tone.success : Tone.accent, height: 6),
                ] else
                  InfoBanner(
                    tone: Tone.danger,
                    icon: Icons.error_outline_rounded,
                    text: 'Table introuvable dans la base',
                  ),
                const SizedBox(height: 16),
                Divider(color: p.line),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          'Modifiée ${fmtRelative(campaign.updatedAt)}',
                          if (campaign.updatedBy != null) 'par ${campaign.updatedBy}',
                        ].join(' '),
                        style: context.textTheme.bodySmall?.copyWith(color: p.faint),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    action,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_Menu> _item(BuildContext context, _Menu value, IconData icon, String label, {bool danger = false}) {
    final p = context.palette;
    final color = danger ? p.danger : p.text;
    return PopupMenuItem(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: danger ? p.danger : p.muted),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.mono = false});

  final IconData icon;
  final String label;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: p.faint),
          const SizedBox(width: 6),
          Text(
            label,
            style: mono
                ? monoStyle(size: 11.5, color: p.muted)
                : context.textTheme.labelMedium?.copyWith(color: p.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
