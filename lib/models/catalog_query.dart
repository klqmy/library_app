import 'entity_kind.dart';

class CatalogQuery {
  final Map<String, String> params;
  CatalogQuery(Uri uri) : params = uri.queryParameters;
  String get search => params['search'] ?? '';
  String get status =>
      const ['active', 'deleted', 'all'].contains(params['status'])
      ? params['status']!
      : 'active';
  int get page => (int.tryParse(params['page'] ?? '') ?? 1).clamp(1, 1000000);
  int get size => const [5, 10, 20].contains(int.tryParse(params['size'] ?? ''))
      ? int.parse(params['size']!)
      : 10;
  String get sort => params['sort']?.split(',').first ?? 'label';
  bool get ascending => params['sort']?.split(',').last != 'desc';
  String get filter => params['filter'] ?? '';

  Map<String, dynamic> toApi(EntityKind kind) {
    final label = switch (kind) {
      EntityKind.books => 'title',
      EntityKind.authors || EntityKind.readers => 'fullName',
      _ => 'name',
    };
    return {
      'page': page,
      'size': size,
      'sort': '${sort == 'label' ? label : sort},${ascending ? 'asc' : 'desc'}',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (status != 'active') 'includeDeleted': true,
      if (status == 'deleted') 'deletedOnly': true,
      if (filter.isNotEmpty)
        ...switch (kind) {
          EntityKind.authors => {'country': filter},
          EntityKind.publishers => {'city': filter},
          EntityKind.genres => {'linked': filter == 'linked'},
          EntityKind.readers => {'cardStatus': filter},
          EntityKind.books => {'available': filter == 'available'},
        },
      if (kind == EntityKind.books)
        for (final key in [
          'genreId',
          'publisherId',
          'authorId',
          'yearFrom',
          'yearTo',
        ])
          if (int.tryParse(params[key] ?? '') != null)
            key: int.parse(params[key]!),
      for (final key in ['__delay', '__fail'])
        if (int.tryParse(params[key] ?? '') != null)
          key: int.parse(params[key]!),
    };
  }
}
