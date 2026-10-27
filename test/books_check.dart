import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/repositories/in_memory_book_repository.dart';
import 'package:library_app/models/book_query.dart';

void main() {
  group('InMemoryBookRepository', () {
    late InMemoryBookRepository repository;

    setUp(() {
      repository = InMemoryBookRepository();
    });

    test('find возвращает все книги без фильтров', () async {
      final result = await repository.find(const BookQuery());
      expect(result.items.length, greaterThan(0));
      expect(result.total, 21);
      print('Тест 1 пройден: найдено ${result.items.length} книг из ${result.total}');
    });

    test('find фильтрует по поисковому запросу', () async {
      final result = await repository.find(
        const BookQuery(search: 'война'),
      );
      expect(result.items.length, 1);
      expect(result.items.first.title, 'Война и мир');
      print('Тест 2 пройден: поиск по "война" нашёл "${result.items.first.title}"');
    });

    test('find фильтрует по жанру', () async {
      final result = await repository.find(
        const BookQuery(genreId: 1),
      );
      expect(result.items.every((b) => b.genreIds.contains(1)), true);
      print('Тест 3 пройден: все книги имеют genreId=1');
    });

    test('find фильтрует по диапазону лет', () async {
      final result = await repository.find(
        const BookQuery(yearFrom: 1850, yearTo: 1900),
      );
      expect(
        result.items.every((b) => b.year >= 1850 && b.year <= 1900),
        true,
      );
      print('Тест 4 пройден: все книги в диапазоне 1850-1900');
    });

    test('find сортирует по году', () async {
      final result = await repository.find(
        const BookQuery(sortField: 'year', sortAscending: true),
      );
      for (int i = 0; i < result.items.length - 1; i++) {
        expect(result.items[i].year <= result.items[i + 1].year, true);
      }
      print('Тест 5 пройден: книги отсортированы по году');
    });

    test('find поддерживает пагинацию', () async {
      final result = await repository.find(
        const BookQuery(page: 1, size: 5),
      );
      expect(result.items.length, lessThanOrEqualTo(5));
      expect(result.page, 1);
      expect(result.size, 5);
      print('Тест 6 пройден: пагинация работает (страница 1, размер 5)');
    });

    test('softDelete помечает книгу как удалённую', () async {
      final initial = await repository.find(const BookQuery());
      final bookId = initial.items.first.id;

      await repository.softDelete(bookId);

      final afterDelete = await repository.find(const BookQuery());
      expect(afterDelete.items.any((b) => b.id == bookId), false);

      final withDeleted = await repository.find(
        const BookQuery(includeDeleted: true),
      );
      expect(withDeleted.items.any((b) => b.id == bookId), true);
      expect(
        withDeleted.items.firstWhere((b) => b.id == bookId).isDeleted,
        true,
      );
      print('Тест 7 пройден: softDelete работает');
    });

    test('restore восстанавливает удалённую книгу', () async {
      final initial = await repository.find(const BookQuery());
      final bookId = initial.items.first.id;

      await repository.softDelete(bookId);
      await repository.restore(bookId);

      final restored = await repository.find(const BookQuery());
      expect(restored.items.any((b) => b.id == bookId), true);
      print('Тест 8 пройден: restore работает');
    });

    test('deleteMany удаляет несколько книг', () async {
      final initial = await repository.find(const BookQuery());
      final idsToDelete = initial.items.take(3).map((b) => b.id).toList();

      final count = await repository.deleteMany(idsToDelete);
      expect(count, 3);

      final afterDelete = await repository.find(const BookQuery());
      expect(
        afterDelete.items.any((b) => idsToDelete.contains(b.id)),
        false,
      );
      print('Тест 9 пройден: deleteMany удалил ${count} книг');
    });
  });
}