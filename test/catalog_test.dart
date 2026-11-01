import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_app/models/entity_kind.dart';
import 'package:library_app/models/reader.dart';
import 'package:library_app/models/library_card.dart';
import 'package:library_app/models/catalog_query.dart';
import 'package:library_app/models/json_values.dart';
import 'package:library_app/repositories/catalog_store.dart';
import 'package:library_app/repositories/catalog_repository.dart';
import 'package:library_app/validation/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late CatalogStore store;
  CatalogRepository repo(EntityKind kind) => CatalogRepository(store, kind);
  Map<String, dynamic> valid(EntityKind kind) => switch (kind) {
    EntityKind.books => {
      ...formData(store.all(kind).first),
      'isbn': '9781234567890',
      'title': 'Новая книга',
    },
    EntityKind.authors => {
      'fullName': 'Тестов Иван',
      'birthYear': 1990,
      'country': 'Россия',
    },
    EntityKind.genres => {'name': 'Новый жанр', 'description': 'Проверка'},
    EntityKind.publishers => {
      'name': 'Новое издательство',
      'city': 'Москва',
      'foundedYear': 2000,
    },
    EntityKind.readers => {
      'fullName': 'Тестова Анна',
      'email': 'test@example.org',
      'phone': '+7 999 123 45 67',
      'cardNumber': 'TEST-100',
      'issuedAt': '2025-01-01',
      'expiresAt': '2028-01-01',
    },
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = await CatalogStore.open(prefs);
  });
  test('начальные книги и авторы ПР2 сохранены', () {
    expect(store.all(EntityKind.books), hasLength(21));
    expect(store.all(EntityKind.authors), hasLength(10));
    expect(store.all(EntityKind.books).first.label, 'Война и мир');
  });
  for (final kind in EntityKind.values) {
    test('${kind.name}: JSON без полей, с null и неверным типом не падает', () {
      final empty = kind.decode({});
      expect(empty.id, 0);
      final nulls = {
        for (final k in store.all(kind).first.toJson().keys) k: null,
      };
      expect(() => kind.decode(nulls), returnsNormally);
      expect(
        () => kind.decode({
          'id': '7',
          'title': [],
          'authorIds': [null, '2', {}, 3],
          'card': [],
        }),
        returnsNormally,
      );
      final initial = store.all(kind).first;
      expect(kind.decode(initial.toJson()).toJson(), initial.toJson());
    });
    test(
      '${kind.name}: создание изменение удаление восстановление и перезапуск',
      () async {
        final r = repo(kind);
        final row = await r.save(valid(kind));
        final reopened = await CatalogStore.open(prefs);
        expect(reopened.byId(kind, row.id)?.toJson(), row.toJson());
        final updated = await r.save(valid(kind), id: row.id);
        expect(updated.id, row.id);
        await r.deleteMany({row.id});
        expect(r.byId(row.id)!.isDeleted, isTrue);
        expect(
          CatalogQuery(
            Uri.parse('/?status=deleted'),
          ).find(r).items.any((e) => e.id == row.id),
          isTrue,
        );
        await r.restore(row.id);
        expect(r.byId(row.id)!.isDeleted, isFalse);
        await r.deleteMany({row.id}, hard: true);
        expect(r.byId(row.id), isNull);
        final afterDelete = await CatalogStore.open(prefs);
        expect(afterDelete.byId(kind, row.id), isNull);
        final next = await r.save(valid(kind));
        expect(next.id, greaterThan(row.id));
      },
    );
    test('${kind.name}: поиск сортировка пагинация и безопасный URL', () {
      final r = repo(kind);
      final first = r.all.first;
      final results = CatalogQuery(
        Uri(queryParameters: {'search': first.label, 'size': '5'}),
      ).find(r);
      expect(results.items.any((e) => e.id == first.id), isTrue);
      final page = CatalogQuery(
        Uri.parse('/?page=2&size=5&sort=id,desc'),
      ).find(r);
      expect(page.items.length, lessThanOrEqualTo(5));
      for (var i = 1; i < page.items.length; i++) {
        expect(page.items[i - 1].id, greaterThan(page.items[i].id));
      }
      expect(
        () => CatalogQuery(Uri.parse('/?page=-2&size=0&sort=bad')).find(r),
        returnsNormally,
      );
    });
  }
  test('валидация обязательности длины чисел формата и дат', () {
    expect(Validators.text('  '), isNotNull);
    expect(Validators.text('abc', max: 2), isNotNull);
    expect(Validators.integer('1.5'), isNotNull);
    expect(Validators.integer('-1', min: 0), isNotNull);
    expect(Validators.email('a@b'), isNotNull);
    expect(Validators.phone('123456789a'), isNotNull);
    expect(Validators.date('2025-02-30'), isNotNull);
    expect(Validators.isbn('978-5-17-090123-4'), isNull);
    expect(Validators.isbn('invalid'), isNotNull);
    expect(LibraryCard.fromJson({'issuedAt': null}).issuedAt, isNull);
    expect(jsonIds([null, 0, '2', 2, {}, -1]), [2]);
  });
  test(
    'ISBN уникален без дефисов и пробелов, текущая запись исключена',
    () async {
      final books = repo(EntityKind.books);
      final first = books.all.first;
      final values = formData(first);
      expect(books.validate(values, id: first.id)['isbn'], isNull);
      values['isbn'] = Validators.normalizeIsbn('${values['isbn']}');
      expect(books.validate(values)['isbn'], isNotNull);
      await expectLater(books.save(values), throwsA(isA<FieldErrors>()));
    },
  );
  test(
    'почта уникальна без учёта регистра и билет принадлежит ровно одному читателю',
    () async {
      final readers = repo(EntityKind.readers);
      final values = valid(EntityKind.readers)
        ..['email'] = 'READER1@EXAMPLE.ORG';
      expect(readers.validate(values)['email'], isNotNull);
      values['email'] = 'new@example.org';
      final row = await readers.save(values) as Reader;
      expect(row.card?.number, values['cardNumber']);
      expect(row.card?.id, isPositive);
      expect(
        readers.validate({...values, 'cardNumber': 'LB-0001'})['cardNumber'],
        isNotNull,
      );
    },
  );
  test('количество экземпляров и даты проверяются совместно', () {
    expect(
      repo(EntityKind.books).validate({
        ...valid(EntityKind.books),
        'copiesAvailable': 20,
        'copiesTotal': 1,
      })['copiesAvailable'],
      isNotNull,
    );
    expect(
      repo(EntityKind.readers).validate({
        ...valid(EntityKind.readers),
        'expiresAt': '2024-01-01',
      })['expiresAt'],
      isNotNull,
    );
  });
  test(
    'издательство со связанными книгами защищено от обоих видов удаления',
    () async {
      final publishers = repo(EntityKind.publishers);
      final count = publishers.references(1);
      expect(count, greaterThan(0));
      await expectLater(
        publishers.deleteMany({1}),
        throwsA(isA<RelationConflict>().having((e) => e.count, 'count', count)),
      );
      await expectLater(
        publishers.deleteMany({1}, hard: true),
        throwsA(isA<RelationConflict>()),
      );
      expect(publishers.byId(1)!.isDeleted, isFalse);
    },
  );
  test('массовая операция атомарна при конфликте связей', () async {
    final r = repo(EntityKind.publishers);
    final unused = await r.save(valid(EntityKind.publishers));
    await expectLater(
      r.deleteMany({unused.id, 1}),
      throwsA(isA<RelationConflict>()),
    );
    expect(r.byId(unused.id)!.isDeleted, isFalse);
  });
  test(
    'жанры сужаются по книгам издательства, новое издательство не блокируется',
    () async {
      final books = repo(EntityKind.books);
      expect(books.genresForPublisher(1).map((g) => g.id), containsAll([1, 2]));
      expect(books.genresForPublisher(1).map((g) => g.id), isNot(contains(11)));
      final publisher = await repo(
        EntityKind.publishers,
      ).save(valid(EntityKind.publishers));
      expect(
        books.genresForPublisher(publisher.id),
        hasLength(store.all(EntityKind.genres).length),
      );
      final genre = await repo(
        EntityKind.genres,
      ).save(valid(EntityKind.genres));
      final book = await books.save({
        ...valid(EntityKind.books),
        'genreIds': [genre.id],
      });
      expect(books.genresForPublisher(1).map((g) => g.id), contains(genre.id));
      expect(book.id, isPositive);
    },
  );
  test(
    'старый формат вызывает уведомление, исходная запись сохраняется',
    () async {
      SharedPreferences.setMockInitialValues({'books_v1': '[old]'});
      prefs = await SharedPreferences.getInstance();
      final reopened = await CatalogStore.open(prefs);
      expect(reopened.notice, isNotNull);
      expect(prefs.getString('books_v1'), '[old]');
    },
  );
  test(
    'повреждённое хранилище и неизвестная версия восстанавливаются с резервной копией',
    () async {
      for (final raw in [
        'broken json',
        jsonEncode({'schemaVersion': 999, 'entities': {}}),
      ]) {
        await prefs.setString(CatalogStore.storageKey, raw);
        final reopened = await CatalogStore.open(prefs);
        expect(reopened.notice, isNotNull);
        expect(reopened.all(EntityKind.books), hasLength(21));
        expect(prefs.getString('${CatalogStore.storageKey}_backup'), raw);
      }
    },
  );
  test(
    'быстрые сохранения выполняются последовательно и не теряют записи',
    () async {
      final r = repo(EntityKind.authors);
      final rows = await Future.wait(
        List.generate(
          5,
          (i) => r.save({
            ...valid(EntityKind.authors),
            'fullName': 'Тестов Иван $i',
          }),
        ),
      );
      expect(rows.map((r) => r.id).toSet(), hasLength(5));
      final reopened = await CatalogStore.open(prefs);
      expect(reopened.all(EntityKind.authors), hasLength(15));
    },
  );
}
