import '../models/app_user.dart';
import '../models/entity_kind.dart';
import '../models/loan.dart';
import '../models/page_result.dart';
import 'catalog_store.dart';

class LibraryService {
  final CatalogStore store;
  LibraryService(this.store);
  Future<PageResult<Loan>> loans(int page) async {
    final data = await store.api.get(
      '/loans',
      query: {'page': page, 'size': 10, 'sort': 'id,desc'},
    );
    return PageResult(
      items: [
        for (final row in data['items'] as List)
          Loan.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      page: (data['page'] as num).toInt(),
      size: (data['size'] as num).toInt(),
      total: (data['total'] as num).toInt(),
    );
  }

  Future<void> extend(int id) async {
    await store.api.post('/loans/$id/extend');
  }

  Future<void> returnLoan(int id) async {
    await store.api.post('/loans/$id/return');
    store.changed(EntityKind.books);
  }

  Future<PageResult<AppUser>> users(int page) async {
    final data = await store.api.get(
      '/users',
      query: {'page': page, 'size': 10, 'sort': 'id,asc'},
    );
    return PageResult(
      items: [
        for (final row in data['items'] as List)
          AppUser.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      page: (data['page'] as num).toInt(),
      size: (data['size'] as num).toInt(),
      total: (data['total'] as num).toInt(),
    );
  }

  Future<void> changeRole(int id, Role role) async {
    await store.api.put('/users/$id', data: {'role': role.name});
  }

  Future<Map<String, int>> statistics() async {
    final data = await store.api.get('/stats');
    return {
      for (final e in (data as Map).entries)
        e.key.toString(): (e.value as num).toInt(),
    };
  }
}
