import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/models/entity_kind.dart';
import 'package:library_app/repositories/catalog_store.dart';
import 'package:library_app/repositories/library_service.dart';
import 'package:library_app/screens/catalog_list_screen.dart';
import 'package:library_app/screens/entity_form_screen.dart';
import 'package:library_app/screens/home_screen.dart';
import 'package:library_app/state/form_guard.dart';
import 'package:library_app/validation/validators.dart';
import 'package:library_app/widgets/app_page.dart';
import 'package:library_app/widgets/request_state.dart';
import 'package:library_app/widgets/responsive_grid.dart';
import 'api_test.dart' as support;
import 'auth_test.dart' as sessions;

Future<sessions.Fixture> ready(
  WidgetTester tester, {
  String role = 'reader',
  Future<ResponseBody> Function(RequestOptions)? respond,
}) async => (await tester.runAsync(() async {
  final f = await sessions.fixture(
    respond: (o) async {
      if (o.path == '/auth/login') {
        return support.jsonResponse({
          ...sessions.session(),
          'user': {...sessions.profile, 'role': role},
        });
      }
      return respond?.call(o) ?? support.jsonResponse(support.page([]));
    },
  );
  await f.auth.login('reader', 'reader123');
  return f;
}))!;

Future<void> mount(
  WidgetTester tester,
  sessions.Fixture f,
  Widget screen,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final store = CatalogStore(f.client);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, __) => screen)],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: f.auth),
        ChangeNotifierProvider(create: (_) => store),
        Provider(create: (_) => FormGuard()),
        Provider(create: (_) => LibraryService(store)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(useMaterial3: true),
      ),
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('обязательное поле отклоняет пустую строку и пробелы', () {
    expect(Validators.text(''), isNotNull);
    expect(Validators.text('   '), isNotNull);
  });
  test(
    'непустое название принимается',
    () => expect(Validators.text('Война и мир'), isNull),
  );
  test('электронная почта проверяет формат', () {
    expect(Validators.email('reader@example.com'), isNull);
    expect(Validators.email('reader@'), isNotNull);
  });
  test('год проверяет границы и целое число', () {
    expect(Validators.integer('1869', min: 1450, max: 2027), isNull);
    expect(Validators.integer('12.5', min: 1450, max: 2027), isNotNull);
    expect(Validators.integer('1400', min: 1450, max: 2027), isNotNull);
  });
  test('ISBN нормализуется перед проверкой', () {
    expect(Validators.normalizeIsbn('978-5-17-118366-4'), '9785171183664');
    expect(Validators.isbn('978-5-17-118366-4'), isNull);
  });
  test('модель книги допускает отсутствующие поля', () {
    final book = Book.fromJson({'id': 1});
    expect(book.title, '');
    expect(book.authorIds, isEmpty);
    expect(book.copiesAvailable, 0);
  });
  test('модель книги читает развёрнутые связи API', () {
    final book = Book.fromJson({
      'id': 1,
      'publisher': {'id': 2},
      'authors': [
        {'id': 3},
      ],
      'genres': [
        {'id': 4},
      ],
    });
    expect(book.publisherId, 2);
    expect(book.authorIds, [3]);
    expect(book.genreIds, [4]);
  });
  test('служебные поля книги не отправляются при сохранении', () {
    final book = Book.fromJson({
      'id': 1,
      'copiesAvailable': 2,
      'deletedAt': '2026-01-01T00:00:00Z',
    });
    expect(book.isDeleted, isTrue);
    expect(book.toRequestJson().containsKey('id'), isFalse);
    expect(book.toRequestJson().containsKey('copiesAvailable'), isFalse);
    expect(book.toRequestJson().containsKey('deletedAt'), isFalse);
  });

  testWidgets('во время загрузки виден индикатор', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RequestState())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка данных с сервера…'), findsOneWidget);
  });
  testWidgets('пустой каталог показывает сообщение вместо индикатора', (
    tester,
  ) async {
    final f = await ready(tester);
    await mount(
      tester,
      f,
      CatalogListScreen(kind: EntityKind.books, uri: Uri.parse('/books')),
    );
    await settle(tester);
    expect(find.textContaining('Записи не найдены.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets(
    'ошибка сервера и повтор восстанавливают список без перезагрузки',
    (tester) async {
      var requests = 0;
      final f = await ready(
        tester,
        respond: (o) async {
          if (o.path == '/books' && ++requests == 1) {
            return support.jsonResponse({
              'message': 'Сервер временно недоступен',
            }, 500);
          }
          return support.jsonResponse(support.page([]));
        },
      );
      await mount(
        tester,
        f,
        CatalogListScreen(kind: EntityKind.books, uri: Uri.parse('/books')),
      );
      await settle(tester);
      expect(find.textContaining('Ошибка сервера (500)'), findsOneWidget);
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.textContaining('Записи не найдены.'), findsOneWidget);
      expect(requests, 2);
    },
  );
  testWidgets('пустая форма автора не отправляется в API', (tester) async {
    final f = await ready(tester, role: 'librarian');
    await mount(tester, f, const EntityFormScreen(kind: EntityKind.authors));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Создать'));
    await tester.tap(find.text('Создать'));
    await tester.pump();
    expect(find.text('Обязательное поле'), findsWidgets);
    expect(
      f.adapter.calls.where((o) => o.method == 'POST' && o.path == '/authors'),
      isEmpty,
    );
  });
  testWidgets('читатель не видит управление пользователями', (tester) async {
    final f = await ready(tester);
    await mount(tester, f, const HomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('Пользователи и роли'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ResponsiveGrid),
        matching: find.text('Мои выдачи'),
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'изменение ширины перестраивает навигацию и сетку без потери сессии',
    (tester) async {
      final f = await ready(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, f, const HomeScreen());
      for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Ширина $width');
        expect(
          find.byType(NavigationBar),
          width < 600 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(NavigationRail),
          width < 600 ? findsNothing : findsOneWidget,
        );
        final grid = find.byType(ResponsiveGrid);
        final catalog = find.descendant(
          of: grid,
          matching: find.text('Каталог'),
        );
        final loans = find.descendant(
          of: grid,
          matching: find.text('Мои выдачи'),
        );
        if (width < 600) {
          expect(
            tester.getTopLeft(loans).dy,
            greaterThan(tester.getTopLeft(catalog).dy),
          );
        } else {
          expect(
            tester.getTopLeft(loans).dy,
            closeTo(tester.getTopLeft(catalog).dy, 1),
          );
        }
        expect(f.auth.accessToken, 'access-1');
      }
    },
  );
  testWidgets('формы пяти сущностей не переполняются при четырёх ширинах', (
    tester,
  ) async {
    final f = await ready(tester, role: 'librarian');
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final kind in EntityKind.values) {
        await mount(tester, f, EntityFormScreen(kind: kind));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${kind.name}: $width');
        expect(find.byType(AppPage), findsOneWidget);
      }
    }
  });
}
