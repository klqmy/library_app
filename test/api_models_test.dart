import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_app/models/author.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/models/catalog_query.dart';
import 'package:library_app/models/entity_kind.dart';
import 'package:library_app/models/genre.dart';
import 'package:library_app/models/publisher.dart';
import 'package:library_app/models/reader.dart';
import 'package:library_app/forms/field_spec.dart';
import 'package:library_app/repositories/catalog_repository.dart';
import 'package:library_app/repositories/catalog_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('книга читает вложенные связи API, на запись отправляет ID', () {
    final book = Book.fromJson({
      'id': 1,
      'title': 'Война и мир',
      'isbn': '978-5-17-118366-4',
      'year': 1869,
      'pages': 1300,
      'publisher': {'id': 1, 'name': 'АСТ'},
      'authors': [
        {'id': 1, 'fullName': 'Толстой Л. Н.'},
      ],
      'genres': [
        {'id': 2, 'name': 'Роман'},
      ],
      'copiesTotal': 4,
      'copiesAvailable': 2,
      'createdAt': '2026-08-01T09:00:00Z',
      'deletedAt': null,
    });
    expect(book.publisherId, 1);
    expect(book.authorIds, [1]);
    expect(book.genreIds, [2]);
    expect(book.createdAt, DateTime.utc(2026, 8, 1, 9));
    expect(book.toRequestJson(), {
      'title': 'Война и мир',
      'isbn': '978-5-17-118366-4',
      'year': 1869,
      'pages': 1300,
      'publisherId': 1,
      'authorIds': [1],
      'genreIds': [2],
      'copiesTotal': 4,
    });
    expect(Book.fromJson(book.toJson()).toJson(), book.toJson());
  });

  test('повреждённые и пустые вложенные связи книги безопасны', () {
    final book = Book.fromJson({
      'publisher': null,
      'authors': [
        null,
        'bad',
        {'id': 3},
        {'id': 3},
      ],
      'genres': {},
      'createdAt': 'not a date',
    });
    expect(book.publisherId, 0);
    expect(book.authorIds, [3]);
    expect(book.genreIds, isEmpty);
    expect(book.createdAt, isNull);
  });

  test('автор, жанр и издательство соответствуют разделу 4 контракта', () {
    final author = {
      'id': 1,
      'fullName': 'Толстой Л. Н.',
      'birthYear': 1828,
      'country': 'Россия',
      'deletedAt': null,
    };
    final genre = {
      'id': 2,
      'name': 'Роман',
      'description': 'Крупная форма повествования',
      'deletedAt': null,
    };
    final publisher = {
      'id': 1,
      'name': 'АСТ',
      'city': 'Москва',
      'foundedYear': 1990,
      'deletedAt': null,
    };
    expect(Author.fromJson(author).toJson(), author);
    expect(Genre.fromJson(genre).toJson(), genre);
    expect(Publisher.fromJson(publisher).toJson(), publisher);
    expect(Author.fromJson({'birthYear': null}).birthYear, isNull);
    expect(Publisher.fromJson({'foundedYear': []}).foundedYear, isNull);
  });

  test('читатель разбирает card и сохраняет отдельный ID билета', () {
    final reader = Reader.fromJson({
      'id': 1,
      'fullName': 'Смирнов П. А.',
      'email': 'smirnov@example.com',
      'phone': '+7 900 000-00-00',
      'card': {
        'id': 75,
        'number': 'RC-000001',
        'issuedAt': '2026-01-15T00:00:00Z',
        'expiresAt': '2027-01-15T00:00:00Z',
      },
      'deletedAt': null,
    });
    expect(reader.fullName, 'Смирнов П. А.');
    expect(reader.card?.id, 75);
    expect(reader.card?.issuedAt, DateTime.utc(2026, 1, 15));
    expect(reader.toJson(), isNot(contains('libraryCard')));
    expect(Reader.fromJson(reader.toJson()).toJson(), reader.toJson());
    expect(Reader.fromJson({'card': null}).card, isNull);
    expect(Reader.fromJson({'card': null}).toJson()['card'], isNull);
  });

  test(
    'новые поля форм имеют проверку диапазона, неизвестный год допустим',
    () {
      final birth = fieldsFor(
        EntityKind.authors,
      ).firstWhere((f) => f.name == 'birthYear');
      final founded = fieldsFor(
        EntityKind.publishers,
      ).firstWhere((f) => f.name == 'foundedYear');
      for (final field in [birth, founded]) {
        expect(field.validate!(''), isNull);
        expect(field.validate!('0'), isNotNull);
        expect(field.validate!('1.5'), isNotNull);
        expect(field.validate!('${DateTime.now().year + 1}'), isNotNull);
        expect(field.validate!('1990'), isNull);
      }
      expect(
        fieldsFor(EntityKind.authors).map((f) => f.name),
        contains('fullName'),
      );
      expect(
        fieldsFor(EntityKind.publishers).map((f) => f.name),
        isNot(contains('genreIds')),
      );
      expect(founded.validate!('1399'), isNotNull);
      final year = fieldsFor(
        EntityKind.books,
      ).firstWhere((f) => f.name == 'year');
      expect(year.validate!('${DateTime.now().year + 1}'), isNotNull);
    },
  );

  test(
    'переход v3 → v4 сохраняет записи, ID, корзину, билет и счётчики',
    () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      await CatalogStore.open(prefs);
      final legacy =
          jsonDecode(prefs.getString(CatalogStore.storageKey)!)
              as Map<String, dynamic>;
      legacy['schemaVersion'] = 3;
      final entities = legacy['entities'] as Map;
      (entities['authors'] as List).add({
        'id': 100,
        'firstName': 'Иван',
        'lastName': 'Проверкин',
        'country': 'Россия',
        'deletedAt': '2026-01-01T00:00:00Z',
      });
      legacy['nextIds']['authors'] = 120;
      final first = entities['readers'][0] as Map;
      first.remove('fullName');
      first['firstName'] = 'Анна';
      first['lastName'] = 'Волкова';
      first['libraryCard'] = first.remove('card');
      first['libraryCard']['id'] = 75;
      first['libraryCard']['issuedAt'] = '2025-09-01T00:00:00.000';
      entities['publishers'][0].remove('foundedYear');
      entities['publishers'][0]['country'] = 'Россия';
      entities['publishers'][0]['genreIds'] = [1, 2];
      entities['books'][0]['deletedAt'] = '2026-01-01T00:00:00Z';
      final raw = jsonEncode(legacy);
      SharedPreferences.setMockInitialValues({
        CatalogStore.legacyStorageKey: raw,
      });
      prefs = await SharedPreferences.getInstance();
      final store = await CatalogStore.open(prefs);
      expect(store.notice, isNotNull);
      expect(store.byId(EntityKind.authors, 100)?.label, 'Проверкин Иван');
      expect(store.byId(EntityKind.authors, 100)?.isDeleted, isTrue);
      expect(store.byId(EntityKind.books, 1)?.isDeleted, isTrue);
      final reader = store.byId(EntityKind.readers, 1) as Reader;
      expect(reader.fullName, 'Волкова Анна');
      expect(reader.card?.id, 75);
      expect(reader.card?.issuedAt, DateTime.utc(2025, 9, 1));
      expect(prefs.getString(CatalogStore.legacyStorageKey), raw);
      final saved = jsonDecode(prefs.getString(CatalogStore.storageKey)!);
      expect(saved['schemaVersion'], 4);
      expect(saved['entities']['readers'][0], isNot(contains('libraryCard')));
      final authors = CatalogRepository(store, EntityKind.authors);
      final author = await authors.save({
        'fullName': 'Новый автор',
        'country': 'Россия',
        'birthYear': '',
      });
      expect(author.id, 120);
      final updated =
          await CatalogRepository(
                store,
                EntityKind.readers,
              ).save(formData(reader), id: 1)
              as Reader;
      expect(updated.card?.id, 75);
      final reopened = await CatalogStore.open(prefs);
      expect(reopened.notice, isNull);
      expect(reopened.byId(EntityKind.readers, 1)?.toJson(), updated.toJson());
    },
  );

  test('фильтр издательств использует город из контракта', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await CatalogStore.open(
      await SharedPreferences.getInstance(),
    );
    final repo = CatalogRepository(store, EntityKind.publishers);
    final row = await repo.save({
      'name': 'Новое издательство',
      'city': 'Казань',
      'foundedYear': '2010',
    });
    expect(row.toJson()['foundedYear'], 2010);
    final page = CatalogQuery(
      Uri(queryParameters: {'filter': 'Казань'}),
    ).find(repo);
    expect(page.items.map((p) => p.id), [row.id]);
  });

  test(
    'повторное имя жанра даёт ошибку поля, редактирование своей записи разрешено',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await CatalogStore.open(
        await SharedPreferences.getInstance(),
      );
      final genres = CatalogRepository(store, EntityKind.genres);
      final values = {'name': ' роман ', 'description': ''};
      expect(genres.validate(values)['name'], isNotNull);
      expect(genres.validate(values, id: 1)['name'], isNull);
      await expectLater(genres.save(values), throwsA(isA<FieldErrors>()));
    },
  );
}
