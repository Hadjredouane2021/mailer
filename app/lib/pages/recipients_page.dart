import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../ui/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'shell.dart';

/// Explorateur des tables de destinataires (remplace index.php + « reset sent » d'admin.php).
class RecipientsPage extends StatefulWidget {
  const RecipientsPage({super.key, this.initialTable});

  final String? initialTable;

  @override
  State<RecipientsPage> createState() => _RecipientsPageState();
}

class _RecipientsPageState extends State<RecipientsPage> {
  late final Api _api = context.read<Session>().api;
  final _search = TextEditingController();
  final _resultsKey = GlobalKey();
  List<TableInfo> _tables = const [];
  String? _table;
  String _query = '';
  String _status = 'all';
  int _page = 1;
  int _pageSize = 50;

  RecipientPage? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(RecipientsPage old) {
    super.didUpdateWidget(old);
    if (widget.initialTable != null && widget.initialTable != old.initialTable) _select(widget.initialTable!);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _tables = await _api.tables();
      final wanted = widget.initialTable;
      _table = _tables.any((t) => t.name == wanted) ? wanted : (_tables.isEmpty ? null : _tables.first.name);
      await _fetch();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _fetch() async {
    final table = _table;
    if (table == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.recipients(table, q: _query, status: _status, page: _page, pageSize: _pageSize),
        _api.tables(),
      ]);
      if (!mounted || table != _table) return;
      setState(() {
        _data = results[0] as RecipientPage;
        _tables = results[1] as List<TableInfo>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(String table) {
    _search.clear();
    setState(() {
      _table = table;
      _query = '';
      _page = 1;
      _data = null;
    });
    _fetch();
  }

  void _onSearch(String value) {
    _query = value.trim();
    _page = 1;
    _fetch();
  }

  /// Change de page puis ramène le haut des résultats à l'écran.
  Future<void> _goTo(int page) async {
    setState(() => _page = page);
    await _fetch();
    final target = _resultsKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  void _setPageSize(int size) {
    setState(() {
      _pageSize = size;
      _page = 1;
    });
    _fetch();
  }

  TableInfo? get _info => _tables.where((t) => t.name == _table).firstOrNull;

  Future<void> _reset() async {
    final info = _info;
    if (info == null) return;
    final ok = await confirmAction(
      context,
      title: 'Réinitialiser « ${info.name} » ?',
      message:
          'Les ${fmtInt(info.sent)} destinataires marqués envoyés repasseront à sent=0 '
          'et recevront à nouveau la prochaine campagne lancée sur cette table.',
      confirmLabel: 'Réinitialiser',
      destructive: true,
      icon: Icons.restart_alt_rounded,
    );
    if (!ok) return;
    try {
      final updated = await _api.resetTable(info.name);
      if (mounted) showToast(context, '$updated ligne(s) remises à sent=0.');
      _fetch();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool sent) async {
    final data = _data;
    if (data == null) return;
    try {
      await _api.setSent(_table!, [row[data.idColumn]], sent);
      _fetch();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final info = _info;
    final canEdit = context.watch<Session>().canEdit;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Base « mail »',
            title: 'Destinataires',
            subtitle: 'Contenu des tables et statut d’envoi (colonne sent).',
            actions: [
              if (_tables.isNotEmpty)
                SizedBox(
                  width: compact ? double.infinity : 280,
                  child: DropdownButtonFormField<String>(
                    style: context.textTheme.bodyMedium,
                    key: ValueKey(_table),
                    initialValue: _table,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(radiusMd),
                    dropdownColor: p.surface,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.table_rows_outlined, size: 18)),
                    items: [
                      for (final t in _tables)
                        DropdownMenuItem(
                          value: t.name,
                          child: Text('${t.name}  ·  ${fmtInt(t.total)}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : _select(v),
                  ),
                ),
              if (canEdit)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.danger,
                    side: BorderSide(color: p.danger.withValues(alpha: 0.35)),
                  ),
                  onPressed: info == null || info.sent == 0 || info.busy ? null : _reset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 19),
                  label: const Text('Réinitialiser'),
                ),
            ],
          ),
          if (_error != null && _data == null)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              tone: Tone.danger,
              title: 'Chargement impossible',
              message: '$_error',
              action: OutlinedButton(onPressed: _fetch, child: const Text('Réessayer')),
            )
          else if (_tables.isEmpty && !_loading)
            const EmptyState(
              icon: Icons.table_rows_outlined,
              title: 'Aucune table de destinataires',
              message: 'Une table doit contenir au moins les colonnes email et sent.',
            )
          else ...[
            if (info != null) _summary(context, info, compact),
            const SizedBox(height: 18),
            _toolbar(context, info, compact),
            const SizedBox(height: 14),
            KeyedSubtree(key: _resultsKey, child: _results(context, canEdit)),
          ],
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, TableInfo? info, bool compact) {
    final search = SearchField(
      controller: _search,
      hint: 'Rechercher (e-mail, nom, société…)',
      debounce: const Duration(milliseconds: 350),
      onChanged: _onSearch,
    );
    final filters = FilterScroller(
      child: PillTabs<String>(
        value: _status,
        items: [
          PillTab('all', label: 'Tous', count: info?.total),
          PillTab('pending', label: 'En attente', count: info?.pending),
          PillTab('sent', label: 'Envoyés', count: info?.sent),
        ],
        onChanged: (s) {
          setState(() {
            _status = s;
            _page = 1;
          });
          _fetch();
        },
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [search, const SizedBox(height: 10), filters],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: search),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: filters),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, TableInfo info, bool compact) {
    final p = context.palette;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          value: info.progress,
          size: 60,
          stroke: 7,
          tone: info.pending == 0 && info.total > 0 ? Tone.success : Tone.accent,
          child: Text(
            fmtPercent(info.progress),
            style: context.textTheme.labelSmall?.copyWith(color: p.text, letterSpacing: 0, fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.name,
                style: monoStyle(size: 16, weight: FontWeight.w600, color: p.text),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Identifiant : ${info.idColumn} · ${info.columns.length} colonnes',
                style: context.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (info.busy) ...[
                const SizedBox(height: 6),
                const StatusPill('Envoi en cours', tone: Tone.info, pulse: true),
              ],
            ],
          ),
        ),
      ],
    );
    final stats = [
      Stat(label: 'Total', value: fmtInt(info.total)),
      Stat(label: 'Envoyés', value: fmtInt(info.sent), tone: Tone.success),
      Stat(label: 'En attente', value: fmtInt(info.pending), tone: Tone.warning),
    ];
    return Panel(
      padding: const EdgeInsets.all(20),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) Container(width: 1, height: 32, color: p.line),
                        Expanded(child: Center(child: stats[i])),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                for (final s in stats) ...[const SizedBox(width: 36), s],
                const SizedBox(width: 8),
              ],
            ),
    );
  }

  Widget _results(BuildContext context, bool canEdit) {
    final p = context.palette;
    final data = _data;
    if (data == null) return const Skeleton(height: 420, radius: radiusLg);
    final busy = _info?.busy ?? false;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 2, child: _loading ? const LinearProgressIndicator(minHeight: 2) : null),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _loading ? 0.55 : 1,
            child: data.rows.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun destinataire',
                    message: _query.isEmpty
                        ? 'Aucune ligne ne correspond à ce filtre.'
                        : 'Aucun résultat pour « $_query ».',
                  )
                : SelectionArea(
                    child: _RecipientTable(data: data, canEdit: canEdit, busy: busy, onToggle: _toggle),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Pager(
              page: data.page,
              pageSize: _pageSize,
              total: data.total,
              unit: 'destinataires',
              onPage: _goTo,
              onPageSize: _setPageSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau des destinataires : colonnes élastiques (bureau), défilement horizontal
/// si l'espace manque, cartes empilées sur mobile.
class _RecipientTable extends StatelessWidget {
  const _RecipientTable({required this.data, required this.canEdit, required this.busy, required this.onToggle});

  final RecipientPage data;
  final bool canEdit;
  final bool busy;
  final void Function(Map<String, dynamic> row, bool sent) onToggle;

  static const _hPad = 20.0;
  static const _actionWidth = 136.0;

  /// Largeur minimale (d'après le contenu de la page) et poids d'élargissement de chaque colonne.
  (double, int) _spec(String column) {
    if (column == 'sent') return (116, 0);
    final mono = column == 'email' || column == 'uuid' || column == data.idColumn;
    var longest = column.length;
    for (final row in data.rows) {
      longest = math.max(longest, math.min(40, _cell(row[column]).length));
    }
    final width = (longest * (mono ? 7.6 : 7.2) + 30).clamp(64.0, column == 'email' ? 280.0 : 250.0);
    final flex = column == 'email' ? 4 : (width > 150 ? 2 : 1);
    return (width, flex);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final specs = [for (final col in data.columns) _spec(col)];
      final action = canEdit ? _actionWidth : 0.0;
      final minTotal = specs.fold<double>(0, (a, s) => a + s.$1) + action;
      final available = c.maxWidth - _hPad * 2;
      // Cartes sur mobile, et sur tablette quand le tableau ne tiendrait pas en largeur.
      if (c.maxWidth < 560 || (available < minTotal && c.maxWidth < 900)) {
        return Column(
          children: [
            for (var i = 0; i < data.rows.length; i++)
              _RecipientCard(
                row: data.rows[i],
                columns: data.columns,
                idColumn: data.idColumn,
                first: i == 0,
                canEdit: canEdit,
                busy: busy,
                onToggle: onToggle,
              ),
          ],
        );
      }

      final columns = data.columns;
      final extra = math.max(0.0, available - minTotal);
      final flexSum = specs.fold<int>(0, (a, s) => a + s.$2);
      var widths = [for (final s in specs) s.$1 + (flexSum == 0 ? 0 : extra * s.$2 / flexSum)];
      var tableMin = minTotal;
      // Léger manque de place : on resserre les colonnes de texte (valeurs tronquées) plutôt que de faire défiler.
      if (available < minTotal) {
        final fixed =
            action +
            [
              for (var i = 0; i < specs.length; i++)
                if (columns[i] == 'sent') specs[i].$1,
            ].fold<double>(0, (a, w) => a + w);
        final shrink = (available - fixed) / (minTotal - fixed);
        if (shrink >= 0.75) {
          widths = [for (var i = 0; i < specs.length; i++) columns[i] == 'sent' ? specs[i].$1 : specs[i].$1 * shrink];
          tableMin = available;
        }
      }
      final width = math.max(available, tableMin) + _hPad * 2;

      final table = SizedBox(
        width: width,
        child: Column(
          children: [
            _header(context, columns, widths, action),
            for (var i = 0; i < data.rows.length; i++)
              _RecipientRow(
                row: data.rows[i],
                columns: columns,
                widths: widths,
                idColumn: data.idColumn,
                actionWidth: action,
                canEdit: canEdit,
                busy: busy,
                onToggle: onToggle,
              ),
          ],
        ),
      );
      return available >= tableMin ? table : SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
    },
  );

  Widget _header(BuildContext context, List<String> columns, List<double> widths, double action) {
    final p = context.palette;
    final style = context.textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceHigh.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: widths[i],
              child: Text(columns[i].toUpperCase(), style: style, overflow: TextOverflow.ellipsis),
            ),
          if (action > 0)
            SizedBox(
              width: action,
              child: Text('ACTION', style: style, textAlign: TextAlign.right),
            ),
        ],
      ),
    );
  }
}

bool _isSent(Map<String, dynamic> row) => '${row['sent']}' == '1';

String _cell(Object? v) => v == null || '$v'.isEmpty ? '—' : '$v';

Widget _toggleButton(
  BuildContext context,
  Map<String, dynamic> row,
  bool busy,
  void Function(Map<String, dynamic>, bool) onToggle,
) {
  final p = context.palette;
  final sent = _isSent(row);
  final button = TextButton.icon(
    onPressed: busy ? null : () => onToggle(row, !sent),
    icon: Icon(sent ? Icons.replay_rounded : Icons.done_rounded, size: 16),
    label: Text(sent ? 'Renvoyer' : 'Envoyé'),
    style: TextButton.styleFrom(
      foregroundColor: sent ? p.warning : p.success,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 34),
      textStyle: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
  return Tooltip(
    message: sent ? 'Remettre à sent=0 : recevra le prochain envoi' : 'Marquer comme envoyé (sent=1)',
    child: button,
  );
}

class _RecipientRow extends StatefulWidget {
  const _RecipientRow({
    required this.row,
    required this.columns,
    required this.widths,
    required this.idColumn,
    required this.actionWidth,
    required this.canEdit,
    required this.busy,
    required this.onToggle,
  });

  final Map<String, dynamic> row;
  final List<String> columns;
  final List<double> widths;
  final String idColumn;
  final double actionWidth;
  final bool canEdit;
  final bool busy;
  final void Function(Map<String, dynamic> row, bool sent) onToggle;

  @override
  State<_RecipientRow> createState() => _RecipientRowState();
}

class _RecipientRowState extends State<_RecipientRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = widget.row;
    final sent = _isSent(row);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _RecipientTable._hPad, vertical: 7),
        decoration: BoxDecoration(
          color: _hover ? p.text.withValues(alpha: 0.03) : null,
          border: Border(bottom: BorderSide(color: p.line.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            for (var i = 0; i < widget.columns.length; i++)
              SizedBox(
                width: widget.widths[i],
                child: widget.columns[i] == 'sent'
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(sent ? 'Envoyé' : 'En attente', tone: sent ? Tone.success : Tone.warning),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          _cell(row[widget.columns[i]]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _monoColumn(widget.columns[i])
                              ? monoStyle(size: 12.5, color: p.text)
                              : context.textTheme.bodyMedium,
                        ),
                      ),
              ),
            if (widget.actionWidth > 0)
              SizedBox(
                width: widget.actionWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _toggleButton(context, row, widget.busy, widget.onToggle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _monoColumn(String c) => c == 'email' || c == 'uuid' || c == widget.idColumn;
}

/// Version mobile : une carte par destinataire.
class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.row,
    required this.columns,
    required this.idColumn,
    required this.first,
    required this.canEdit,
    required this.busy,
    required this.onToggle,
  });

  final Map<String, dynamic> row;
  final List<String> columns;
  final String idColumn;
  final bool first;
  final bool canEdit;
  final bool busy;
  final void Function(Map<String, dynamic> row, bool sent) onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sent = _isSent(row);
    final details = columns.where((c) => c != 'email' && c != 'sent').take(6).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 11),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.line.withValues(alpha: 0.7))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cell(row['email']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 13, weight: FontWeight.w600, color: p.text),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(sent ? 'Envoyé' : 'En attente', tone: sent ? Tone.success : Tone.warning),
              const SizedBox(width: 6),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 2,
              children: [
                for (final c in details)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$c ',
                          style: TextStyle(color: p.faint),
                        ),
                        TextSpan(
                          text: _cell(row[c]),
                          style: TextStyle(color: p.muted),
                        ),
                      ],
                    ),
                    style: context.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
          if (canEdit) Align(alignment: Alignment.centerRight, child: _toggleButton(context, row, busy, onToggle)),
        ],
      ),
    );
  }
}
