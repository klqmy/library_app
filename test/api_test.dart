import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/core/api_client.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/models/catalog_query.dart';
import 'package:library_app/models/entity_kind.dart';
import 'package:library_app/repositories/catalog_repository.dart';
import 'package:library_app/repositories/catalog_store.dart';
import 'package:library_app/state/catalog_list_controller.dart';

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  final calls = <RequestOptions>[];
  MockAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, dynamic> page(
  List<Object> rows, {
  int current = 1,
  int total = 1,
}) => {'items': rows, 'page': current, 'size': 5, 'total': total};
ApiClient client(MockAdapter adapter) => ApiClient(
  dio: Dio()..httpClientAdapter = adapter,

  retryPause: Duration.zero,
);
const author = {
  'id': 1,
  'fullName': 'Автор',
  'country': 'Россия',
  'birthYear': null,
};

void main() {
  test('серверная страница и параметры поиска, фильтра, сортировки', () async {
    final adapter = MockAdapter(
      (_) async => jsonResponse(page([author], current: 2, total: 9)),
    );
    final store = CatalogStore(client(adapter));
    final result = await CatalogRepository(store, EntityKind.authors).find(
      CatalogQuery(
        Uri.parse(
          '/authors?search=Автор&filter=Россия&sort=birthYear,desc&page=2&size=5',
        ),
      ),
    );
    expect(result.page, 2);
    expect(result.total, 9);
    expect(result.items.single.label, 'Автор');
    expect(adapter.calls.single.queryParameters, {
      'page': 2,
      'size': 5,
      'search': 'Автор',
      'country': 'Россия',
      'sort': 'birthYear,desc',
    });
    store.dispose();
  });
  test('422 сохраняет ошибки полей для формы', () async {
    final adapter = MockAdapter(
      (_) async => jsonResponse({
        'message': 'Ошибка валидации',
        'errors': {'isbn': 'ISBN уже занят', 'card.number': 'Номер занят'},
      }, 422),
    );
    final api = client(adapter);
    await expectLater(
      api.post('/books', data: {}),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.errors['isbn'], 'isbn', 'ISBN уже занят')
            .having(
              (e) => e.errors['card.number'],
              'card.number',
              'Номер занят',
            ),
      ),
    );
    expect(adapter.calls.length, 1);
    api.close();
  });
  test('нет сети: не более трёх попыток чтения', () async {
    final adapter = MockAdapter(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    final api = client(adapter);
    await expectLater(api.get('/books'), throwsA(isA<NetworkException>()));
    expect(adapter.calls.length, 3);
    api.close();
  });
  test('временный таймаут: третья попытка получает данные', () async {
    var count = 0;
    final adapter = MockAdapter((o) async {
      if (++count < 3) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return jsonResponse(page([]));
    });
    final api = client(adapter);
    expect((await api.get('/books'))['items'], isEmpty);
    expect(count, 3);
    api.close();
  });
  test('создание не повторяется после потери соединения', () async {
    final adapter = MockAdapter(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    final api = client(adapter);
    await expectLater(
      api.post('/books', data: {}),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.calls.length, 1);
    api.close();
  });
  test(
    '500 отображается как ошибка сервера без автоматического повтора',
    () async {
      final adapter = MockAdapter(
        (_) async => jsonResponse({'message': 'Ошибка'}, 500),
      );
      final api = client(adapter);
      await expectLater(api.get('/books'), throwsA(isA<ServerException>()));
      expect(adapter.calls.length, 1);
      api.close();
    },
  );
  for (final entry in <int, Type>{
    401: UnauthorizedException,
    403: ForbiddenException,
    404: NotFoundException,
    409: ConflictException,
  }.entries) {
    test('${entry.key} преобразуется в доменное исключение', () async {
      final adapter = MockAdapter(
        (_) async => jsonResponse({'message': 'Понятное сообщение'}, entry.key),
      );
      final api = client(adapter);
      await expectLater(
        api.get('/books'),
        throwsA(
          predicate(
            (e) =>
                e.runtimeType == entry.value &&
                e.toString() == 'Понятное сообщение',
          ),
        ),
      );
      api.close();
    });
  }
  test('отменённый запрос не отправляется и не повторяется', () async {
    final adapter = MockAdapter((_) async => jsonResponse(page([])));
    final api = client(adapter);
    final cancel = RequestToken()..cancel();
    await expectLater(
      api.get('/books', cancel: cancel),
      throwsA(isA<RequestCancelledException>()),
    );
    expect(adapter.calls, isEmpty);
    api.close();
  });
  test(
    'справочник загружается один раз и сбрасывается после изменения',
    () async {
      final adapter = MockAdapter((_) async => jsonResponse(page([author])));
      final store = CatalogStore(client(adapter));
      await Future.wait([
        store.reference(EntityKind.authors),
        store.reference(EntityKind.authors),
      ]);
      await store.reference(EntityKind.authors);
      expect(adapter.calls.length, 1);
      store.changed(EntityKind.authors);
      await store.reference(EntityKind.authors);
      expect(adapter.calls.length, 2);
      store.dispose();
    },
  );
  test('поздний ответ старого поиска не заменяет новый', () async {
    final old = Completer<ResponseBody>();
    final adapter = MockAdapter((o) async {
      if (o.queryParameters['search'] == 'старый') return old.future;
      if (o.path == '/authors' && o.queryParameters['search'] == 'новый') {
        return jsonResponse(
          page([
            {...author, 'fullName': 'Новый результат'},
          ]),
        );
      }
      return jsonResponse(page([]));
    });
    final store = CatalogStore(client(adapter));
    final controller = CatalogListController(
      CatalogRepository(store, EntityKind.authors),
    );
    final first = controller.load(
      CatalogQuery(Uri.parse('/authors?search=старый')),
    );
    await Future<void>.delayed(Duration.zero);
    await controller.load(CatalogQuery(Uri.parse('/authors?search=новый')));
    old.complete(
      jsonResponse(
        page([
          {...author, 'fullName': 'Старый результат'},
        ]),
      ),
    );
    await first;
    expect(controller.result.items.single.label, 'Новый результат');
    expect(controller.status, LoadStatus.data);
    expect(
      store.all(EntityKind.authors).where((x) => x.label == 'Старый результат'),
      isEmpty,
    );
    controller.dispose();
    store.dispose();
  });
  test('в кэше списка остаётся последняя страница', () async {
    final adapter = MockAdapter(
      (o) async => jsonResponse(
        page(
          [
            {...author, 'id': o.queryParameters['page'] ?? 1},
          ],
          current: (o.queryParameters['page'] ?? 1) as int,
          total: 10,
        ),
      ),
    );
    final store = CatalogStore(client(adapter));
    final repo = CatalogRepository(store, EntityKind.readers);
    final controller = CatalogListController(repo);
    await controller.load(CatalogQuery(Uri.parse('/readers?page=1')));
    await controller.load(CatalogQuery(Uri.parse('/readers?page=2')));
    expect(controller.result.items.single.id, 2);
    expect(store.all(EntityKind.readers).map((x) => x.id), [2]);
    controller.dispose();
    store.dispose();
  });
}
