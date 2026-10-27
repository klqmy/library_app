import '../models/author.dart';
import '../models/page_result.dart';

abstract interface class AuthorRepository {
  Future<PageResult<Author>> find({
    String search = '',
    String? country,
    String sortField = 'lastName',
    bool sortAscending = true,
    int page = 1,
    int size = 10,
    bool includeDeleted = false,
  });
  Future<Author?> findById(int id);
  Future<Author> create(Author author);
  Future<Author> update(Author author);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}