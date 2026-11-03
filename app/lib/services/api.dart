import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;

  @override
  String toString() => message;
}

/// Client de l'API Mailler Studio (Next.js). Toutes les routes sont sous /api.
class Api {
  Api({required String baseUrl, required this.token, this.onUnauthorized})
    : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  final String token;

  /// Appelé quand le serveur refuse le jeton (session expirée, compte désactivé…).
  final void Function()? onUnauthorized;
  final http.Client _client = http.Client();

  static const _timeout = Duration(seconds: 30);

  Map<String, String> get _headers => {
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return Uri.parse('$baseUrl/api$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  /// URL absolue d'une ressource renvoyée par l'API (ex. /api/uploads/x.png).
  String absolute(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  /// Aperçu HTML ouvrable dans un navigateur (le jeton passe en paramètre).
  String previewUrl(String campaignId) => _uri('/campaigns/$campaignId/preview', {'token': token}).toString();

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, Object?>? query}) async {
    final request = http.Request(method, _uri(path, query))..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Le serveur ne répond pas (délai dépassé).');
    } catch (_) {
      throw ApiException('Serveur injoignable : $baseUrl. Vérifiez que l’API Next.js est démarrée.');
    }
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    dynamic json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      json = null;
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && token.isNotEmpty) onUnauthorized?.call();
      final message = json is Map && json['error'] != null ? '${json['error']}' : 'Erreur ${response.statusCode}';
      throw ApiException(message, status: response.statusCode);
    }
    return json;
  }

  Future<dynamic> get(String path, [Map<String, Object?>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const {});
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);
  List<Map<String, dynamic>> _list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ── Authentification & compte
  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(_map(await post('/auth/login', {'email': email, 'password': password})));
  Future<AuthResult> setup({
    required String name,
    required String email,
    required String password,
    String? setupKey,
  }) async => AuthResult.fromJson(
    _map(
      await post('/auth/setup', {
        'name': name,
        'email': email,
        'password': password,
        if (setupKey != null && setupKey.isNotEmpty) 'setupKey': setupKey,
      }),
    ),
  );
  Future<AppUser> me() async => AppUser.fromJson(_map(await get('/auth/me')));
  Future<AppUser> updateMe({required String name, required String email}) async =>
      AppUser.fromJson(_map(await put('/auth/me', {'name': name, 'email': email})));
  Future<AuthResult> changePassword(String current, String next) async => AuthResult.fromJson(
    _map(await put('/auth/password', {'currentPassword': current, 'newPassword': next})),
  );

  // ── Utilisateurs (administrateurs)
  Future<List<AppUser>> users() async => _list(await get('/users')).map(AppUser.fromJson).toList();
  Future<AppUser> createUser(Map<String, dynamic> data) async => AppUser.fromJson(_map(await post('/users', data)));
  Future<AppUser> updateUser(String id, Map<String, dynamic> data) async =>
      AppUser.fromJson(_map(await put('/users/$id', data)));
  Future<void> deleteUser(String id) => delete('/users/$id');

  // ── Santé & tableau de bord
  Future<Health> health() async => Health.fromJson(_map(await get('/health')));
  Future<DashboardStats> stats() async => DashboardStats.fromJson(_map(await get('/stats')));

  // ── Campagnes
  Future<List<Campaign>> campaigns() async => _list(await get('/campaigns')).map(Campaign.fromJson).toList();
  Future<Campaign> campaign(String id) async => Campaign.fromJson(_map(await get('/campaigns/$id')));
  Future<Campaign> createCampaign(Map<String, dynamic> data) async =>
      Campaign.fromJson(_map(await post('/campaigns', data)));
  Future<Campaign> updateCampaign(String id, Map<String, dynamic> data) async =>
      Campaign.fromJson(_map(await put('/campaigns/$id', data)));
  Future<Campaign> duplicateCampaign(String id) async =>
      Campaign.fromJson(_map(await post('/campaigns/$id/duplicate')));
  Future<void> deleteCampaign(String id) => delete('/campaigns/$id');

  Future<Preview> preview({
    required String subject,
    required String bodyHtml,
    required String altBody,
    String? table,
  }) async => Preview.fromJson(
    _map(
      await post('/preview', {
        'subject': subject,
        'bodyHtml': bodyHtml,
        'altBody': altBody,
        if (table != null && table.isNotEmpty) 'table': table,
      }),
    ),
  );

  Future<CheckResult> sendTest(String id, String to) async =>
      CheckResult.fromJson(_map(await post('/campaigns/$id/test', {'to': to})));

  // ── Envois
  Future<Job> run(String campaignId) async => Job.fromJson(_map(await post('/campaigns/$campaignId/run')));
  Future<List<Job>> jobs({int limit = 100}) async =>
      _list(await get('/jobs', {'limit': limit})).map(Job.fromJson).toList();
  Future<JobDetail> job(String id, {int since = 0}) async =>
      JobDetail.fromJson(_map(await get('/jobs/$id', {'since': since})));
  Future<Job> control(String id, String action) async => Job.fromJson(_map(await post('/jobs/$id/$action')));

  // ── Destinataires
  Future<List<TableInfo>> tables() async => _list(await get('/tables')).map(TableInfo.fromJson).toList();
  Future<RecipientPage> recipients(
    String table, {
    String? q,
    String status = 'all',
    int page = 1,
    int pageSize = 50,
  }) async => RecipientPage.fromJson(
    _map(await get('/tables/$table/recipients', {'q': q, 'status': status, 'page': page, 'pageSize': pageSize})),
  );
  Future<int> setSent(String table, List<Object?> ids, bool sent) async =>
      (_map(await patch('/tables/$table/recipients', {'ids': ids, 'sent': sent}))['updated'] as num).toInt();
  Future<int> resetTable(String table) async => (_map(await post('/tables/$table/reset'))['updated'] as num).toInt();

  // ── Réglages
  Future<AppSettings> settings() async => AppSettings.fromJson(_map(await get('/settings')));
  Future<AppSettings> saveSettings(Map<String, dynamic> patch) async =>
      AppSettings.fromJson(_map(await put('/settings', patch)));
  Future<CheckResult> testDb([Map<String, dynamic>? db]) async =>
      CheckResult.fromJson(_map(await post('/settings/test-db', {'db': ?db})));
  Future<CheckResult> testSmtp([Map<String, dynamic>? smtp]) async =>
      CheckResult.fromJson(_map(await post('/settings/test-smtp', {'smtp': ?smtp})));

  /// Téléverse une image, renvoie son chemin (/api/uploads/…) à insérer dans le HTML.
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', _uri('/uploads'))
      ..headers.addAll({if (token.isNotEmpty) 'Authorization': 'Bearer $token'})
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
      return '${_map(_decode(response))['url']}';
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Échec du téléversement de l’image.');
    }
  }
}
