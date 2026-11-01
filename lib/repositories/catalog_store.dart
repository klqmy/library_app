import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/book.dart';

class CatalogStore extends ChangeNotifier {
  final ApiClient api;
  CatalogStore(this.api);
  final _pages = <EntityKind, List<CatalogEntity>>{};
  final _references = <EntityKind, List<CatalogEntity>>{};
  final _pending = <EntityKind, Future<List<CatalogEntity>>>{};
  final _single = <EntityKind, CatalogEntity>{};
  final _suggestions = <int, List<CatalogEntity>>{};
  final _counts = <int, int>{};
  final totals = <EntityKind, int>{};
  List<Book> _related = [];
  String? _relatedKey;
  int revision = 0;

  List<CatalogEntity> all(EntityKind kind) =>
      _references[kind] ?? _pages[kind] ?? [];
  CatalogEntity? byId(EntityKind kind, int id) {
    if (_single[kind]?.id == id) return _single[kind];
    for (final row in [...all(kind), ...?_pages[kind]]) {
      if (row.id == id) return row;
    }
    return null;
  }

  int? references(int id) => _counts[id];
  void cachePage(EntityKind kind, List<CatalogEntity> rows, int total) {
    _pages[kind] = List.unmodifiable(rows);
    totals[kind] = total;
  }

  List<CatalogEntity> decodeRows(EntityKind kind, dynamic data) {
    final rows = (data['items'] as List).cast<Map<String, dynamic>>();
    if (kind == EntityKind.genres) {
      for (final row in rows) {
        if (row['bookCount'] is num) {
          _counts[row['id'] as int] = (row['bookCount'] as num).toInt();
        }
      }
    }
    return rows.map(kind.decode).toList();
  }

  Future<List<CatalogEntity>> reference(EntityKind kind) {
    if (_references.containsKey(kind)) return Future.value(_references[kind]!);
    return _pending.putIfAbsent(kind, () async {
      try {
        final rows = <CatalogEntity>[];
        var page = 1;
        while (true) {
          final data = await api.get(
            kind.path,
            query: {'size': 100, 'page': page},
          );
          rows.addAll(decodeRows(kind, data));
          if (page * 100 >= (data['total'] as num)) break;
          page++;
        }
        _references[kind] = List.unmodifiable(rows);
        return _references[kind]!;
      } finally {
        _pending.remove(kind);
      }
    });
  }

  Future<void> ensureReferences() async {
    await Future.wait([
      for (final kind in [
        EntityKind.authors,
        EntityKind.genres,
        EntityKind.publishers,
      ])
        reference(kind),
    ]);
  }

  Future<CatalogEntity> fetchById(EntityKind kind, int id) async {
    final data = await api.get(
      '${kind.path}/$id',
      query: {'includeDeleted': true},
    );
    final row = kind.decode(Map<String, dynamic>.from(data));
    _single[kind] = row;
    return row;
  }

  Future<void> prepare(EntityKind kind, {int? id, bool detail = false}) async {
    if (kind == EntityKind.books ||
        kind == EntityKind.authors ||
        kind == EntityKind.genres ||
        kind == EntityKind.publishers) {
      await ensureReferences();
    }
    if (id != null) await fetchById(kind, id);
    if (kind == EntityKind.books && !detail) {
      await Future.wait([
        for (final p in all(EntityKind.publishers)) _loadGenres(p.id),
      ]);
    }
    if (detail &&
        id != null &&
        [
          EntityKind.authors,
          EntityKind.genres,
          EntityKind.publishers,
        ].contains(kind)) {
      final key = switch (kind) {
        EntityKind.authors => 'authorId',
        EntityKind.genres => 'genreId',
        _ => 'publisherId',
      };
      final data = await api.get(
        '/books',
        query: {key: id, 'size': 100, 'includeDeleted': true},
      );
      _related = decodeRows(EntityKind.books, data).cast<Book>();
      _relatedKey = '${kind.name}:$id';
    }
  }

  Future<void> _loadGenres(int id) async {
    if (_suggestions.containsKey(id)) return;
    final data = await api.get(
      '/genres',
      query: {'publisherId': id, 'size': 100},
    );
    final rows = decodeRows(EntityKind.genres, data);
    _suggestions[id] = rows.isEmpty ? all(EntityKind.genres) : rows;
  }

  List<CatalogEntity> genresForPublisher(int id) =>
      _suggestions[id] ?? all(EntityKind.genres);
  List<Book> relatedBooks(EntityKind kind, int id) =>
      _relatedKey == '${kind.name}:$id' ? _related : [];
  void changed(EntityKind kind) {
    _pages.remove(kind);
    _references.remove(kind);
    _suggestions.clear();
    _counts.clear();
    _related = [];
    revision++;
    notifyListeners();
  }

  Future<void> summary() async {
    await Future.wait([
      for (final kind in EntityKind.values)
        () async {
          final data = await api.get(kind.path, query: {'size': 1});
          totals[kind] = (data['total'] as num).toInt();
        }(),
    ]);
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }
}
