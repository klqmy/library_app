import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_app/core/api_client.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/models/app_user.dart';
import 'package:library_app/repositories/auth_api.dart';
import 'package:library_app/router.dart';
import 'package:library_app/screens/home_screen.dart';
import 'package:library_app/state/auth_notifier.dart';
import 'package:library_app/state/permissions.dart';
import 'package:library_app/state/session_policy.dart';
import 'package:library_app/validation/validators.dart';
import 'api_test.dart' as support;

const profile = {
  'id': 3,
  'username': 'reader',
  'fullName': 'Читатель',
  'email': 'reader@example.com',
  'role': 'reader',
  'readerId': 1,
};
Map<String, Object> session([String suffix = '1']) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'expiresIn': 60,
  'user': profile,
};
typedef Fixture = ({
  AuthNotifier auth,
  ApiClient client,
  SharedPreferences prefs,
  support.MockAdapter adapter,
});
Future<Fixture> fixture({
  Future<ResponseBody> Function(RequestOptions)? respond,
  DateTime Function()? now,
  SessionPolicy? policy,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final adapter = support.MockAdapter(
    respond ??
        (o) async {
          return switch (o.path) {
            '/auth/login' => support.jsonResponse(session()),
            '/auth/me' => support.jsonResponse(profile),
            '/auth/refresh' => support.jsonResponse(session('2')),
            '/auth/logout' => support.jsonResponse({}, 204),
            _ => support.jsonResponse(support.page([])),
          };
        },
  );
  final client = ApiClient(
    baseUrl: 'https://library.test/api',
    dio: Dio()..httpClientAdapter = adapter,
    retryPause: Duration.zero,
  );
  final auth = AuthNotifier(
    prefs,
    AuthApi(client),
    now: now,
    policy: policy,
    automaticTimer: false,
  );
  client.tokenProvider = () => auth.accessToken;
  client.refreshSession = auth.refreshTokens;
  client.expireSession = () => auth.logout(reason: SessionEnd.expired);
  addTearDown(() {
    auth.dispose();
    client.close();
  });
  return (auth: auth, client: client, prefs: prefs, adapter: adapter);
}

void main() {
  const matrix = {
    Operation.viewCatalog: {Role.reader, Role.librarian, Role.admin},
    Operation.manageCatalog: {Role.librarian, Role.admin},
    Operation.manageReaders: {Role.librarian, Role.admin},
    Operation.hardDelete: {Role.admin},
    Operation.restore: {Role.admin},
    Operation.manageUsers: {Role.admin},
    Operation.statistics: {Role.admin},
    Operation.ownLoans: {Role.reader},
    Operation.loanDesk: {Role.librarian},
    Operation.extendOwnLoan: {Role.reader},
  };
  for (final rule in matrix.entries) {
    test('права операции ${rule.key.name} для трёх ролей', () {
      for (final role in Role.values) {
        expect(
          Permissions.allows(role, rule.key),
          rule.value.contains(role),
          reason: role.name,
        );
      }
    });
  }
  test('у каждой роли есть отдельный защищённый экран', () {
    expect(requiredOperation('/my-loans'), Operation.ownLoans);
    expect(requiredOperation('/loans'), Operation.loanDesk);
    expect(requiredOperation('/admin/users'), Operation.manageUsers);
    expect(requiredOperation('/books/new'), Operation.manageCatalog);
    expect(requiredOperation('/authors/3/edit'), Operation.manageCatalog);
  });
  test('from сохраняет внутренний адрес и отклоняет внешний редирект', () {
    expect(safeDestination('/books/7?tab=info'), '/books/7?tab=info');
    for (final value in [
      'https://example.com',
      '//example.com',
      '/login',
      'javascript:alert(1)',
      '',
    ]) {
      expect(safeDestination(value), '/');
    }
  });
  test('проверка пароля: длина, цифра и специальный символ', () {
    for (final value in ['', '123!', 'Password!', 'Password123', 'пароль123']) {
      expect(Validators.password(value), isNotNull, reason: value);
    }
    expect(Validators.password('Пароль123!'), isNull);
    expect(Validators.passwordRules('Passw0rd!').values, everyElement(isTrue));
  });
  test('предупреждение начинается за 30 секунд до трёх минут', () {
    final start = DateTime.utc(2026, 11, 1);
    const policy = SessionPolicy();
    expect(
      policy
          .check(start.add(const Duration(seconds: 149)), start, start)
          .warningSeconds,
      isNull,
    );
    expect(
      policy
          .check(start.add(const Duration(seconds: 150)), start, start)
          .warningSeconds,
      30,
    );
    expect(
      policy.check(start.add(const Duration(seconds: 180)), start, start).ended,
      SessionEnd.inactivity,
    );
  });
  test('общий срок сессии истекает даже при постоянной активности', () {
    final start = DateTime.utc(2026, 11, 1);
    final current = start.add(const Duration(minutes: 30));
    expect(
      const SessionPolicy().check(current, start, current).ended,
      SessionEnd.duration,
    );
  });
  test('вход сохраняет токены и профиль, но не пароль', () async {
    final f = await fixture();
    await f.auth.login('reader', 'reader123');
    expect(f.auth.isAuthenticated, isTrue);
    expect(f.prefs.getString(AuthNotifier.accessKey), 'access-1');
    expect(f.prefs.getString(AuthNotifier.refreshKey), 'refresh-1');
    expect(
      f.prefs.getString(AuthNotifier.userKey),
      isNot(contains('reader123')),
    );
    expect(f.prefs.getKeys().any((k) => k.contains('password')), isFalse);
    await f.client.get('/books');
    expect(f.adapter.calls.last.headers['Authorization'], 'Bearer access-1');
  });
  test(
    'после восстановления сохраняется исходное время начала сессии',
    () async {
      var current = DateTime.utc(2026, 11, 1);
      final f = await fixture(now: () => current);
      await f.auth.login('reader', 'reader123');
      final started = f.prefs.getInt(AuthNotifier.startedKey);
      current = current.add(const Duration(minutes: 1));
      final restored = AuthNotifier(
        f.prefs,
        AuthApi(f.client),
        now: () => current,
        automaticTimer: false,
      );
      f.client.tokenProvider = () => restored.accessToken;
      await restored.restore();
      expect(restored.isAuthenticated, isTrue);
      expect(f.prefs.getInt(AuthNotifier.startedKey), started);
      restored.dispose();
    },
  );
  test(
    'активность убирает предупреждение, а выход удаляет все данные сессии',
    () async {
      var current = DateTime.utc(2026, 11, 1);
      final f = await fixture(now: () => current);
      await f.auth.login('reader', 'reader123');
      current = current.add(const Duration(seconds: 150));
      f.auth.checkSession();
      expect(f.auth.warningSeconds, 30);
      f.auth.activity();
      expect(f.auth.warningSeconds, isNull);
      await f.auth.logout();
      expect(f.auth.isAuthenticated, isFalse);
      for (final key in [
        AuthNotifier.accessKey,
        AuthNotifier.refreshKey,
        AuthNotifier.userKey,
        AuthNotifier.uiRoleKey,
        AuthNotifier.startedKey,
        AuthNotifier.activityKey,
      ]) {
        expect(f.prefs.containsKey(key), isFalse);
      }
    },
  );
  test('перезагрузка не обнуляет три минуты неактивности', () async {
    var current = DateTime.utc(2026, 11, 1);
    final f = await fixture(now: () => current);
    await f.auth.login('reader', 'reader123');
    current = current.add(const Duration(seconds: 181));
    await f.auth.restore();
    expect(f.auth.isAuthenticated, isFalse);
    expect(f.auth.notice, contains('трёх минут'));
    expect(f.prefs.getString(AuthNotifier.accessKey), isNull);
  });
  test('ошибка входа 401 не запускает обновление токена', () async {
    final f = await fixture(
      respond: (o) async =>
          support.jsonResponse({'message': 'Неверный логин или пароль'}, 401),
    );
    await expectLater(
      f.auth.login('reader', 'wrong'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(f.adapter.calls.map((o) => o.path), ['/auth/login']);
    expect(f.auth.isAuthenticated, isFalse);
  });
  test('401 обновляет токен и повторяет исходный запрос один раз', () async {
    final f = await fixture(
      respond: (o) async {
        if (o.path == '/auth/login') return support.jsonResponse(session());
        if (o.path == '/auth/refresh') {
          return support.jsonResponse(session('2'));
        }
        if (o.headers['Authorization'] == 'Bearer access-1') {
          return support.jsonResponse({'message': 'Токен истёк'}, 401);
        }
        return support.jsonResponse(support.page([]));
      },
    );
    await f.auth.login('reader', 'reader123');
    final started = f.prefs.getInt(AuthNotifier.startedKey);
    await f.client.get('/books');
    expect(f.auth.accessToken, 'access-2');
    expect(f.adapter.calls.where((o) => o.path == '/auth/refresh').length, 1);
    expect(f.adapter.calls.where((o) => o.path == '/books').length, 2);
    expect(f.prefs.getInt(AuthNotifier.startedKey), started);
  });
  test('параллельные ответы 401 используют одно обновление', () async {
    final f = await fixture(
      respond: (o) async {
        if (o.path == '/auth/login') return support.jsonResponse(session());
        if (o.path == '/auth/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return support.jsonResponse(session('2'));
        }
        if (o.headers['Authorization'] == 'Bearer access-1') {
          return support.jsonResponse({}, 401);
        }
        return support.jsonResponse(support.page([]));
      },
    );
    await f.auth.login('reader', 'reader123');
    await Future.wait([
      f.client.get('/books'),
      f.client.get('/authors'),
      f.client.get('/genres'),
    ]);
    expect(f.adapter.calls.where((o) => o.path == '/auth/refresh').length, 1);
    expect(f.auth.accessToken, 'access-2');
  });
  test(
    'недействительный refresh завершает сессию без цикла запросов',
    () async {
      final f = await fixture(
        respond: (o) async {
          if (o.path == '/auth/login') return support.jsonResponse(session());
          if (o.path == '/auth/logout') return support.jsonResponse({}, 204);
          return support.jsonResponse({'message': 'Токен недействителен'}, 401);
        },
      );
      await f.auth.login('reader', 'reader123');
      await expectLater(
        f.client.get('/books'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(f.auth.isAuthenticated, isFalse);
      expect(f.adapter.calls.where((o) => o.path == '/auth/refresh').length, 1);
      expect(f.adapter.calls.where((o) => o.path == '/books').length, 1);
      expect(f.prefs.getString(AuthNotifier.refreshKey), isNull);
    },
  );
  test(
    'повторный 401 после обновления тоже завершает сессию без цикла',
    () async {
      final f = await fixture(
        respond: (o) async {
          if (o.path == '/auth/login') return support.jsonResponse(session());
          if (o.path == '/auth/refresh') {
            return support.jsonResponse(session('2'));
          }
          if (o.path == '/auth/logout') return support.jsonResponse({}, 204);
          return support.jsonResponse({}, 401);
        },
      );
      await f.auth.login('reader', 'reader123');
      await expectLater(
        f.client.get('/books'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(f.auth.isAuthenticated, isFalse);
      expect(f.adapter.calls.where((o) => o.path == '/auth/refresh').length, 1);
      expect(f.adapter.calls.where((o) => o.path == '/books').length, 2);
    },
  );
  testWidgets(
    'подмена роли показывает кнопки, но токен остаётся читательским и API возвращает 403',
    (tester) async {
      final f = (await tester.runAsync(() async {
        final value = await fixture(
          respond: (o) async {
            if (o.path == '/auth/login') return support.jsonResponse(session());
            return support.jsonResponse({'message': 'Недостаточно прав'}, 403);
          },
        );
        await value.auth.login('reader', 'reader123');
        return value;
      }))!;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: f.auth,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      expect(find.text('Пользователи и роли'), findsNothing);
      await tester.runAsync(() async {
        await f.prefs.setString(AuthNotifier.uiRoleKey, 'admin');
        await f.auth.syncUiRole();
      });
      await tester.pump();
      expect(find.text('Пользователи и роли'), findsOneWidget);
      expect(f.auth.user!.role, Role.reader);
      expect(f.auth.accessToken, 'access-1');
      await tester.runAsync(
        () => expectLater(
          f.client.get('/users'),
          throwsA(isA<ForbiddenException>()),
        ),
      );
      expect(f.adapter.calls.last.headers['Authorization'], 'Bearer access-1');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
