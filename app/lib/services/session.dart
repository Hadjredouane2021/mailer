import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import 'api.dart';

/// Session utilisateur (serveur, jeton, compte connecté) + préférences locales.
class Session extends ChangeNotifier {
  Session(this._prefs)
    : _serverUrl = _prefs.getString(_kUrl) ?? defaultServerUrl,
      _token = _prefs.getString(_kToken) ?? '',
      _user = _readUser(_prefs),
      _themeMode = ThemeMode.values.asNameMap()[_prefs.getString(_kTheme)] ?? ThemeMode.dark {
    // Ancienne connexion par jeton API (v1) : remplacée par les comptes utilisateurs.
    for (final legacy in const ['api_token', 'connected']) {
      _prefs.remove(legacy);
    }
    _api = _build(_token);
    if (isSignedIn) unawaited(refreshUser());
  }

  /// Servie par l'API elle-même (http://hôte:4100/app/) : même origine. Sinon, API locale.
  static String get defaultServerUrl =>
      kIsWeb && Uri.base.path.startsWith('/app') ? Uri.base.origin : 'http://localhost:4100';
  static const _kUrl = 'server_url';
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kTheme = 'theme_mode';
  static const _kTestEmail = 'test_email';

  final SharedPreferences _prefs;
  String _serverUrl;
  String _token;
  AppUser? _user;
  ThemeMode _themeMode;
  late Api _api;

  /// Message à afficher sur l'écran de connexion (session expirée…).
  String? notice;

  String get serverUrl => _serverUrl;
  String get token => _token;
  AppUser? get user => _user;
  bool get isSignedIn => _token.isNotEmpty && _user != null;
  ThemeMode get themeMode => _themeMode;
  Api get api => _api;
  String get lastTestEmail => _prefs.getString(_kTestEmail) ?? '';

  bool can(Role role) => _user?.role.includes(role) ?? false;
  bool get canEdit => can(Role.editor);
  bool get isAdmin => can(Role.admin);

  static AppUser? _readUser(SharedPreferences prefs) {
    final raw = prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Api _build(String token) => Api(baseUrl: _serverUrl, token: token, onUnauthorized: _onUnauthorized);

  void _onUnauthorized() {
    if (isSignedIn) unawaited(signOut(notice: 'Votre session a expiré. Reconnectez-vous.'));
  }

  /// État du serveur pour l'écran de connexion (premier lancement, base…).
  Future<Health> probe(String url) => Api(baseUrl: url, token: '').health();

  Future<void> signIn(String url, String email, String password) async {
    final candidate = Api(baseUrl: url, token: '');
    await _open(candidate.baseUrl, await candidate.login(email.trim(), password));
  }

  /// Premier lancement : création du compte administrateur.
  Future<void> setup(
    String url, {
    required String name,
    required String email,
    required String password,
    String? setupKey,
  }) async {
    final candidate = Api(baseUrl: url, token: '');
    final result = await candidate.setup(
      name: name.trim(),
      email: email.trim(),
      password: password,
      setupKey: setupKey?.trim(),
    );
    await _open(candidate.baseUrl, result);
  }

  Future<void> _open(String url, AuthResult result) async {
    _serverUrl = url;
    _token = result.token;
    _user = result.user;
    notice = null;
    _api = _build(_token);
    await _prefs.setString(_kUrl, _serverUrl);
    await _prefs.setString(_kToken, _token);
    await _saveUser();
    notifyListeners();
  }

  /// Nouveau jeton après un changement de mot de passe (les autres sessions sont fermées).
  Future<void> replaceSession(AuthResult result) => _open(_serverUrl, result);

  Future<void> signOut({String? notice}) async {
    _token = '';
    _user = null;
    this.notice = notice;
    _api = _build('');
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      updateUser(await _api.me());
    } catch (_) {
      // 401 : déconnexion via onUnauthorized ; serveur injoignable : on garde le profil en cache.
    }
  }

  void updateUser(AppUser user) {
    _user = user;
    unawaited(_saveUser());
    notifyListeners();
  }

  Future<void> _saveUser() async {
    final user = _user;
    if (user != null) await _prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  Future<void> rememberTestEmail(String email) => _prefs.setString(_kTestEmail, email);
}

/// État du serveur et envois en cours (barre supérieure), rafraîchis toutes les 15 s.
class ServerStatus extends ChangeNotifier {
  ServerStatus(this._session) {
    _session.addListener(refresh);
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  final Session _session;
  Timer? _timer;
  Health? health;
  bool reachable = true;
  List<Job> liveJobs = const [];

  Future<void> refresh() async {
    if (!_session.isSignedIn) return;
    final api = _session.api;
    try {
      final results = await Future.wait([api.health(), api.jobs(limit: 10)]);
      health = results[0] as Health;
      liveJobs = (results[1] as List<Job>).where((j) => j.status.isLive).toList();
      reachable = true;
    } catch (_) {
      reachable = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.removeListener(refresh);
    super.dispose();
  }
}
