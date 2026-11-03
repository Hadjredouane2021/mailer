// Modèles renvoyés par l'API Next.js (backend/src/app/api).

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _str(Object? v) => v == null ? '' : '$v';
bool _bool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
DateTime? _date(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;
String? _optional(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

class Health {
  const Health({
    required this.database,
    required this.dryRun,
    required this.version,
    required this.needsSetup,
    required this.setupRequiresKey,
  });

  final bool database;
  final bool dryRun;
  final String version;

  /// Premier lancement : aucun compte n'existe encore.
  final bool needsSetup;
  final bool setupRequiresKey;

  factory Health.fromJson(Map<String, dynamic> j) => Health(
    database: j['database'] == 'ok',
    dryRun: _bool(j['dryRun']),
    version: _str(j['version']),
    needsSetup: _bool(j['needsSetup']),
    setupRequiresKey: _bool(j['setupRequiresKey']),
  );
}

/// Rôles, du moins au plus étendu (l'ordre sert de hiérarchie).
enum Role {
  viewer('Lecteur', 'Consulte le tableau de bord, les campagnes, l’historique et les destinataires.'),
  editor('Éditeur', 'Crée et modifie les campagnes, envoie les tests, lance et pilote les envois.'),
  admin('Administrateur', 'Tous les droits, plus la gestion des utilisateurs et des paramètres serveur.');

  const Role(this.label, this.description);
  final String label;
  final String description;

  bool includes(Role other) => index >= other.index;

  static Role parse(Object? v) => Role.values.firstWhere((r) => r.name == v, orElse: () => Role.viewer);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
    this.createdAt,
    this.lastLoginAt,
    this.service = false,
  });

  final String id;
  final String name;
  final String email;
  final Role role;
  final bool active;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  /// Jeton de service API_TOKEN (pas de compte réel).
  final bool service;

  static final _spaces = RegExp(r'\s+');

  String get firstName => name.trim().split(_spaces).first;

  String get initials {
    final words = name.trim().split(_spaces).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: _str(j['id']),
    name: _str(j['name']),
    email: _str(j['email']),
    role: Role.parse(j['role']),
    active: j['active'] == null ? true : _bool(j['active']),
    createdAt: _date(j['createdAt']),
    lastLoginAt: _date(j['lastLoginAt']),
    service: _bool(j['service']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'active': active,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'lastLoginAt': lastLoginAt?.toUtc().toIso8601String(),
    'service': service,
  };
}

/// Réponse de connexion : jeton de session + utilisateur.
class AuthResult {
  const AuthResult(this.token, this.user);

  final String token;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> j) =>
      AuthResult(_str(j['token']), AppUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
}

class TableCounts {
  const TableCounts({required this.total, required this.sent, required this.pending});

  final int total;
  final int sent;
  final int pending;

  double get progress => total == 0 ? 0 : sent / total;

  factory TableCounts.fromJson(Map<String, dynamic> j) =>
      TableCounts(total: _int(j['total']), sent: _int(j['sent']), pending: _int(j['pending']));
}

class TableInfo extends TableCounts {
  const TableInfo({
    required this.name,
    required this.columns,
    required this.idColumn,
    required super.total,
    required super.sent,
    required super.pending,
    this.busy = false,
  });

  final String name;
  final List<String> columns;
  final String idColumn;
  final bool busy;

  factory TableInfo.fromJson(Map<String, dynamic> j) => TableInfo(
    name: _str(j['name']),
    columns: (j['columns'] as List? ?? const []).map((c) => '$c').toList(),
    idColumn: _str(j['idColumn']),
    total: _int(j['total']),
    sent: _int(j['sent']),
    pending: _int(j['pending']),
    busy: _bool(j['busy']),
  );
}

enum CampaignStatus {
  draft('Brouillon'),
  active('Active'),
  archived('Archivée');

  const CampaignStatus(this.label);
  final String label;

  static CampaignStatus parse(Object? v) =>
      CampaignStatus.values.firstWhere((s) => s.name == v, orElse: () => CampaignStatus.draft);
}

class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    this.description = '',
    this.status = CampaignStatus.draft,
    required this.table,
    required this.fromEmail,
    required this.fromName,
    this.replyTo = '',
    required this.subject,
    this.bodyHtml = '',
    this.altBody = '',
    required this.batchSize,
    required this.pauseSeconds,
    this.updatedAt,
    this.lastRunAt,
    this.source,
    this.tableStats,
    this.activeJobId,
    this.updatedBy,
  });

  final String id;
  final String name;
  final String description;
  final CampaignStatus status;
  final String table;
  final String fromEmail;
  final String fromName;
  final String replyTo;
  final String subject;
  final String bodyHtml;
  final String altBody;
  final int batchSize;
  final int pauseSeconds;
  final DateTime? updatedAt;
  final DateTime? lastRunAt;
  final String? source;
  final TableCounts? tableStats;
  final String? activeJobId;
  final String? updatedBy;

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
    id: _str(j['id']),
    name: _str(j['name']),
    description: _str(j['description']),
    status: CampaignStatus.parse(j['status']),
    table: _str(j['table']),
    fromEmail: _str(j['fromEmail']),
    fromName: _str(j['fromName']),
    replyTo: _str(j['replyTo']),
    subject: _str(j['subject']),
    bodyHtml: _str(j['bodyHtml']),
    altBody: _str(j['altBody']),
    batchSize: _int(j['batchSize']),
    pauseSeconds: _int(j['pauseSeconds']),
    updatedAt: _date(j['updatedAt']),
    lastRunAt: _date(j['lastRunAt']),
    source: j['source'] == null ? null : _str(j['source']),
    tableStats: j['tableStats'] is Map ? TableCounts.fromJson(Map<String, dynamic>.from(j['tableStats'])) : null,
    activeJobId: j['activeJobId'] == null ? null : _str(j['activeJobId']),
    updatedBy: _optional(j['updatedBy']),
  );
}

enum JobStatus {
  running('En cours'),
  waiting('Pause entre lots'),
  paused('En pause'),
  completed('Terminé'),
  cancelled('Arrêté'),
  failed('Échec');

  const JobStatus(this.label);
  final String label;

  bool get isLive => this == running || this == waiting || this == paused;

  static JobStatus parse(Object? v) => JobStatus.values.firstWhere((s) => s.name == v, orElse: () => JobStatus.failed);
}

class Job {
  const Job({
    required this.id,
    required this.campaignId,
    required this.campaignName,
    required this.table,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.finishedAt,
    required this.batchSize,
    required this.pauseSeconds,
    required this.batch,
    required this.sent,
    required this.failed,
    required this.pendingAtStart,
    required this.remaining,
    required this.nextBatchAt,
    required this.error,
    required this.logCount,
    this.startedBy,
  });

  final String id;
  final String campaignId;
  final String campaignName;
  final String table;
  final String subject;
  final JobStatus status;
  final DateTime? createdAt;
  final DateTime? finishedAt;
  final int batchSize;
  final int pauseSeconds;
  final int batch;
  final int sent;
  final int failed;
  final int pendingAtStart;
  final int remaining;
  final DateTime? nextBatchAt;
  final String? error;
  final int logCount;
  final String? startedBy;

  int get processed => sent + failed;
  double get progress => pendingAtStart == 0 ? 1 : (processed / pendingAtStart).clamp(0, 1);
  Duration? get duration => createdAt == null ? null : (finishedAt ?? DateTime.now()).difference(createdAt!);

  factory Job.fromJson(Map<String, dynamic> j) => Job(
    id: _str(j['id']),
    campaignId: _str(j['campaignId']),
    campaignName: _str(j['campaignName']),
    table: _str(j['table']),
    subject: _str(j['subject']),
    status: JobStatus.parse(j['status']),
    createdAt: _date(j['createdAt']),
    finishedAt: _date(j['finishedAt']),
    batchSize: _int(j['batchSize']),
    pauseSeconds: _int(j['pauseSeconds']),
    batch: _int(j['batch']),
    sent: _int(j['sent']),
    failed: _int(j['failed']),
    pendingAtStart: _int(j['pendingAtStart']),
    remaining: _int(j['remaining']),
    nextBatchAt: _date(j['nextBatchAt']),
    error: j['error'] == null ? null : _str(j['error']),
    logCount: _int(j['logCount']),
    startedBy: _optional(j['startedBy']),
  );
}

class JobLog {
  const JobLog({
    required this.index,
    required this.at,
    required this.batch,
    required this.email,
    required this.ok,
    required this.message,
  });

  final int index;
  final DateTime? at;
  final int batch;
  final String email;
  final bool ok;
  final String message;

  factory JobLog.fromJson(Map<String, dynamic> j) => JobLog(
    index: _int(j['i']),
    at: _date(j['at']),
    batch: _int(j['batch']),
    email: _str(j['email']),
    ok: _bool(j['ok']),
    message: _str(j['message']),
  );
}

class JobDetail {
  const JobDetail(this.job, this.log);

  final Job job;
  final List<JobLog> log;

  factory JobDetail.fromJson(Map<String, dynamic> j) => JobDetail(
    Job.fromJson(Map<String, dynamic>.from(j['job'] as Map)),
    _maps(j['log']).map(JobLog.fromJson).toList(),
  );
}

class DailyPoint {
  const DailyPoint(this.date, this.sent, this.failed);

  final DateTime date;
  final int sent;
  final int failed;
}

class DashboardStats {
  const DashboardStats({
    required this.totals,
    required this.tables,
    required this.daily,
    required this.campaignsTotal,
    required this.campaignsActive,
    required this.activeJobs,
    required this.recentJobs,
  });

  final TableCounts totals;
  final List<TableInfo> tables;
  final List<DailyPoint> daily;
  final int campaignsTotal;
  final int campaignsActive;
  final List<Job> activeJobs;
  final List<Job> recentJobs;

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    final campaigns = Map<String, dynamic>.from(j['campaigns'] as Map? ?? const {});
    return DashboardStats(
      totals: TableCounts.fromJson(Map<String, dynamic>.from(j['totals'] as Map)),
      tables: _maps(j['tables']).map(TableInfo.fromJson).toList(),
      daily: _maps(
        j['daily'],
      ).map((d) => DailyPoint(DateTime.parse(_str(d['date'])), _int(d['sent']), _int(d['failed']))).toList(),
      campaignsTotal: _int(campaigns['total']),
      campaignsActive: _int(campaigns['active']),
      activeJobs: _maps(j['activeJobs']).map(Job.fromJson).toList(),
      recentJobs: _maps(j['recentJobs']).map(Job.fromJson).toList(),
    );
  }
}

class RecipientPage {
  const RecipientPage({
    required this.columns,
    required this.idColumn,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.rows,
  });

  final List<String> columns;
  final String idColumn;
  final int total;
  final int page;
  final int pageSize;
  final List<Map<String, dynamic>> rows;

  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();

  factory RecipientPage.fromJson(Map<String, dynamic> j) => RecipientPage(
    columns: (j['columns'] as List? ?? const []).map((c) => '$c').toList(),
    idColumn: _str(j['idColumn']),
    total: _int(j['total']),
    page: _int(j['page']),
    pageSize: _int(j['pageSize']),
    rows: _maps(j['rows']),
  );
}

class Preview {
  const Preview({required this.subject, required this.html, required this.text, required this.sample});

  final String subject;
  final String html;
  final String text;
  final Map<String, dynamic>? sample;

  factory Preview.fromJson(Map<String, dynamic> j) => Preview(
    subject: _str(j['subject']),
    html: _str(j['html']),
    text: _str(j['text']),
    sample: j['sample'] is Map ? Map<String, dynamic>.from(j['sample'] as Map) : null,
  );
}

class AppSettings {
  const AppSettings({required this.db, required this.smtp, required this.defaults});

  final Map<String, dynamic> db;
  final Map<String, dynamic> smtp;
  final Map<String, dynamic> defaults;

  /// Adresses d'expéditeur autorisées pour les campagnes.
  List<String> get senders => [for (final s in defaults['senders'] as List? ?? const []) '$s'];

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    db: Map<String, dynamic>.from(j['db'] as Map),
    smtp: Map<String, dynamic>.from(j['smtp'] as Map),
    defaults: Map<String, dynamic>.from(j['defaults'] as Map),
  );
}

class CheckResult {
  const CheckResult(this.ok, this.message);

  final bool ok;
  final String message;

  factory CheckResult.fromJson(Map<String, dynamic> j) => CheckResult(_bool(j['ok']), _str(j['message']));
}
