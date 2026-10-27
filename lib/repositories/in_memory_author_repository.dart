import '../data/seed_authors.dart';
import '../models/author.dart';
import '../models/page_result.dart';
import 'author_repository.dart';

class InMemoryAuthorRepository implements AuthorRepository {
  final List<Author> _authors = [...seedAuthors];
  int _nextId = seedAuthors.length + 1;

  @override
  Future<PageResult<Author>> find({
    String search = '',
    String? country,
    String sortField = 'lastName',
    bool sortAscending = true,
    int page = 1,
    int size = 10,
    bool includeDeleted = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));

    var rows =
        _authors.where((a) => includeDeleted || !a.isDeleted).toList();

    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      rows = rows
          .where((a) =>
              a.lastName.toLowerCase().contains(needle) ||
              a.firstName.toLowerCase().contains(needle) ||
              a.country.toLowerCase().contains(needle))
          .toList();
    }

    if (country != null) {
      rows = rows.where((a) => a.country == country).toList();
    }

    rows.sort((a, b) {
      final result = switch (sortField) {
        'firstName' => a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase()),
        'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
        _ => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      };
      return sortAscending ? result : -result;
    });

    final total = rows.length;
    final from = (page - 1) * size;
    final to = (from + size) > total ? total : (from + size);
    final items = from >= total ? <Author>[] : rows.sublist(from, to);

    return PageResult(items: items, page: page, size: size, total: total);
  }

  @override
  Future<Author?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _authors.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Author> create(Author author) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newAuthor = Author(
      id: _nextId++,
      firstName: author.firstName,
      lastName: author.lastName,
      country: author.country,
    );
    _authors.add(newAuthor);
    return newAuthor;
  }

  @override
  Future<Author> update(Author author) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final i = _authors.indexWhere((a) => a.id == author.id);
    if (i == -1) throw StateError('Автор ${author.id} не найден');
    _authors[i] = author;
    return author;
  }

  @override
  Future<void> softDelete(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final i = _authors.indexWhere((a) => a.id == id);
    if (i == -1) throw StateError('Автор $id не найден');
    _authors[i] = _authors[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _authors.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> restore(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final i = _authors.indexWhere((a) => a.id == id);
    if (i == -1) throw StateError('Автор $id не найден');
    _authors[i] = _authors[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var count = 0;
    for (final id in ids) {
      final i = _authors.indexWhere((a) => a.id == id && !a.isDeleted);
      if (i != -1) {
        _authors[i] = _authors[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }
}