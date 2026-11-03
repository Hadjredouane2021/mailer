import 'package:intl/intl.dart';

final _int = NumberFormat.decimalPattern('fr');
final _pct = NumberFormat('#,##0.#', 'fr');

// Le séparateur de milliers français (U+202F) n'existe pas dans toutes les
// polices : on utilise une espace insécable classique.
String _nbsp(String s) => s.replaceAll(' ', ' ');

String fmtInt(num value) => _nbsp(_int.format(value));

String fmtPercent(double ratio) => '${_nbsp(_pct.format((ratio * 100).clamp(0, 100)))} %';

String fmtDateTime(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy · HH:mm', 'fr').format(d);

String fmtTime(DateTime? d) => d == null ? '' : DateFormat('HH:mm:ss', 'fr').format(d);

String fmtDayShort(DateTime d) => DateFormat('d MMM', 'fr').format(d);

String fmtToday() {
  final s = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());
  return s[0].toUpperCase() + s.substring(1);
}

String fmtRelative(DateTime? d) {
  if (d == null) return 'jamais';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 45) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
  return DateFormat('d MMM yyyy', 'fr').format(d);
}

String fmtDuration(Duration? d) {
  if (d == null) return '—';
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min ${(d.inSeconds % 60).toString().padLeft(2, '0')} s';
  return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min';
}

String fmtCountdown(Duration d) {
  final s = d.inSeconds.clamp(0, 359999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
