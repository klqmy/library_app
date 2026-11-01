import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../models/app_user.dart';
import '../repositories/auth_api.dart';
import 'permissions.dart';
import 'session_policy.dart';

class AuthNotifier extends ChangeNotifier {
  static const accessKey = 'auth_access_token';
  static const refreshKey = 'auth_refresh_token';
  static const userKey = 'auth_user';
  static const uiRoleKey = 'auth_ui_role';
  static const startedKey = 'auth_started_at';
  static const activityKey = 'auth_last_activity';
  static const reasonKey = 'auth_end_reason';
  final SharedPreferences prefs;
  final AuthApi api;
  final SessionPolicy policy;
  final DateTime Function() now;
  final bool automaticTimer;
  AuthNotifier(
    this.prefs,
    this.api, {
    SessionPolicy? policy,
    DateTime Function()? now,
    this.automaticTimer = true,
  }) : policy =
           policy ??
           SessionPolicy(maximum: Duration(seconds: sessionMaxSeconds)),
       now = now ?? DateTime.now;

  AppUser? _user;
  Role _uiRole = Role.reader;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _started;
  DateTime? _lastActivity;
  DateTime? _lastPersisted;
  Timer? _timer;
  int _epoch = 0;
  bool _syncing = false;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  Future<void> _writes = Future.value();
  int? warningSeconds;
  String? notice;
  String? restoreError;
  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  Role get uiRole => _uiRole;
  bool get isAuthenticated => _user != null && _accessToken != null;
  bool can(Operation operation) =>
      isAuthenticated && Permissions.allows(_uiRole, operation);

  String? _string(String key) =>
      prefs.get(key) is String ? prefs.get(key) as String : null;
  DateTime? _date(String key) => prefs.get(key) is int
      ? DateTime.fromMillisecondsSinceEpoch(prefs.get(key) as int)
      : null;
  Future<void> _write(Future<void> Function() action) {
    _writes = _writes.catchError((_) {}).then((_) => action());
    return _writes;
  }

  static String endMessage(SessionEnd reason) => switch (reason) {
    SessionEnd.manual => 'Вы вышли из системы.',
    SessionEnd.inactivity =>
      'Сессия завершена после трёх минут без действий. Войдите снова.',
    SessionEnd.duration =>
      'Максимальная длительность сессии истекла. Войдите снова.',
    SessionEnd.expired =>
      'Сессия завершена: обновить токен не удалось. Войдите снова.',
  };

  Future<void> restore() async {
    final epoch = ++_epoch;
    try {
      await prefs.reload();
      final reason = _string(reasonKey);
      if (reason != null) {
        notice = endMessage(
          SessionEnd.values.firstWhere(
            (r) => r.name == reason,
            orElse: () => SessionEnd.expired,
          ),
        );
      }
      _accessToken = _string(accessKey);
      _refreshToken = _string(refreshKey);
      if (_accessToken == null || _refreshToken == null) return;
      final cached = _string(userKey);
      if (cached != null) {
        _user = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
      _uiRole = Role.parse(_string(uiRoleKey));
      _started = _date(startedKey);
      _lastActivity = _date(activityKey);
      if (_started == null || _lastActivity == null) {
        await logout(reason: SessionEnd.expired);
        return;
      }
      final state = policy.check(now(), _started!, _lastActivity!);
      if (state.ended != null) {
        await logout(reason: state.ended!);
        return;
      }
      try {
        _user = await api.me();
        _uiRole = _user!.role;
        await _write(() async {
          if (epoch != _epoch) return;
          await prefs.setString(userKey, jsonEncode(_user!.toJson()));
          await prefs.setString(uiRoleKey, _uiRole.name);
        });
      } on UnauthorizedException {
        try {
          await refreshTokens(_accessToken);
        } catch (_) {
          await logout(reason: SessionEnd.expired);
          return;
        }
      } on NetworkException {
        restoreError =
            'Сервер недоступен. Сохранённая сессия оставлена в браузере.';
      }
      if (epoch != _epoch || _disposed) return;
      _startTimer();
      notifyListeners();
    } catch (_) {
      await logout(reason: SessionEnd.expired);
    }
  }

  Future<void> login(String username, String password) async {
    final epoch = ++_epoch;
    final result = await api.login(username, password);
    await _apply(result, epoch, newSession: true);
  }

  Future<void> register(Map<String, dynamic> values) async {
    await api.register(values);
    await login(values['username'] as String, values['password'] as String);
  }

  Future<void> _apply(
    AuthResult result,
    int epoch, {
    bool newSession = false,
  }) async {
    final started = newSession ? now() : _started!;
    final activity = newSession ? now() : _lastActivity!;
    await _write(() async {
      if (epoch != _epoch || _disposed) return;
      await Future.wait([
        prefs.setString(accessKey, result.accessToken),
        prefs.setString(refreshKey, result.refreshToken),
        prefs.setString(userKey, jsonEncode(result.user.toJson())),
        prefs.setString(uiRoleKey, result.user.role.name),
        prefs.setInt(startedKey, started.millisecondsSinceEpoch),
        prefs.setInt(activityKey, activity.millisecondsSinceEpoch),
        prefs.remove(reasonKey),
      ]);
    });
    if (epoch != _epoch || _disposed) throw const RequestCancelledException();
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    _uiRole = result.user.role;
    _started = started;
    _lastActivity = activity;
    _lastPersisted = now();
    notice = null;
    restoreError = null;
    warningSeconds = null;
    _startTimer();
    notifyListeners();
  }

  Future<void> refreshTokens(String? failedToken) async {
    if (_accessToken == null || _refreshToken == null) {
      throw const UnauthorizedException();
    }
    if (failedToken != null && failedToken != _accessToken) return;
    if (_refreshFuture != null) return _refreshFuture!;
    final epoch = _epoch;
    _refreshFuture = () async {
      await prefs.reload();
      final refresh = _string(refreshKey);
      if (refresh == null) throw const UnauthorizedException();
      final result = await api.refresh(refresh);
      await _apply(result, epoch);
    }();
    try {
      await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> logout({SessionEnd reason = SessionEnd.manual}) async {
    final refresh = _refreshToken;
    ++_epoch;
    _timer?.cancel();
    _timer = null;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _uiRole = Role.reader;
    _started = null;
    _lastActivity = null;
    warningSeconds = null;
    restoreError = null;
    notice = endMessage(reason);
    await _write(() async {
      for (final key in [
        accessKey,
        refreshKey,
        userKey,
        uiRoleKey,
        startedKey,
        activityKey,
      ]) {
        await prefs.remove(key);
      }
      await prefs.setString(reasonKey, reason.name);
    });
    if (!_disposed) notifyListeners();
    if (refresh != null) unawaited(api.logout(refresh).catchError((_) {}));
  }

  void activity() {
    if (!isAuthenticated) return;
    checkSession();
    if (!isAuthenticated) return;
    final current = now();
    _lastActivity = current;
    if (_lastPersisted == null ||
        current.difference(_lastPersisted!) >= const Duration(seconds: 1)) {
      final epoch = _epoch;
      _lastPersisted = current;
      unawaited(
        _write(() async {
          if (epoch == _epoch) {
            await prefs.setInt(activityKey, current.millisecondsSinceEpoch);
          }
        }),
      );
    }
    if (warningSeconds != null) {
      warningSeconds = null;
      notifyListeners();
    }
  }

  void checkSession() {
    if (!isAuthenticated) return;
    final status = policy.check(now(), _started!, _lastActivity!);
    if (status.ended != null) {
      unawaited(logout(reason: status.ended!));
      return;
    }
    if (warningSeconds != status.warningSeconds) {
      warningSeconds = status.warningSeconds;
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!automaticTimer) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      checkSession();
      unawaited(syncUiRole());
    });
  }

  Future<void> syncUiRole() async {
    if (!isAuthenticated || _syncing) return;
    _syncing = true;
    try {
      await prefs.reload();
      if (!isAuthenticated || _disposed) return;
      // Это только подсказка для интерфейса. Права проверяются API по токену.
      final hint = Role.parse(_string(uiRoleKey));
      if (hint != _uiRole) {
        _uiRole = hint;
        notifyListeners();
      }
    } catch (_) {
      // Неправильное значение в localStorage не должно ронять приложение.
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _timer?.cancel();
    super.dispose();
  }
}
