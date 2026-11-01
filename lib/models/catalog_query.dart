import 'catalog_entity.dart';
import 'book.dart';
import 'reader.dart';
import 'entity_kind.dart';
import 'page_result.dart';
import '../repositories/catalog_repository.dart';

class CatalogQuery {
  final Map<String, String> params;
  CatalogQuery(Uri uri) : params = uri.queryParameters;
  String get search => params['search'] ?? '';
  String get status =>
      const ['active', 'deleted', 'all'].contains(params['status'])
      ? params['status']!
      : (params['deleted'] == '1' ? 'all' : 'active');
  int get page => (int.tryParse(params['page'] ?? '') ?? 1).clamp(1, 1000000);
  int get size => const [5, 10, 20].contains(int.tryParse(params['size'] ?? ''))
      ? int.parse(params['size']!)
      : 10;
  String get sort => params['sort']?.split(',').first ?? 'label';
  bool get ascending => params['sort']?.split(',').last != 'desc';
  String get filter => params['filter'] ?? '';

  PageResult<CatalogEntity> find(CatalogRepository repository) {
    final needle = search.trim().toLowerCase();
    var rows = repository.all.where((r) {
      if (status == 'active' && r.isDeleted ||
          status == 'deleted' && !r.isDeleted) {
        return false;
      }
      if (needle.isNotEmpty &&
          !'${r.label} ${r.toJson().values.join(' ')}'.toLowerCase().contains(
            needle,
          )) {
        return false;
      }
      if (r is Book) {
        final genre = int.tryParse(params['genreId'] ?? '');
        final publisher = int.tryParse(params['publisherId'] ?? '');
        final from = int.tryParse(params['yearFrom'] ?? '');
        final to = int.tryParse(params['yearTo'] ?? '');
        if (genre != null && !r.genreIds.contains(genre)) return false;
        if (publisher != null && r.publisherId != publisher) return false;
        if (from != null && r.year < from || to != null && r.year > to) {
          return false;
        }
        if (filter == 'available' && r.copiesAvailable == 0) return false;
        if (filter == 'unavailable' && r.copiesAvailable > 0) return false;
      } else if (r is Reader) {
        final expiry = r.card?.expiresAt;
        final now = DateTime.now();
        final active =
            expiry != null &&
            !expiry.isBefore(DateTime.utc(now.year, now.month, now.day));
        if (filter == 'valid' && !active || filter == 'expired' && active) {
          return false;
        }
      } else if (repository.kind == EntityKind.genres) {
        final count = repository.references(r.id);
        if (filter == 'linked' && count == 0 ||
            filter == 'empty' && count > 0) {
          return false;
        }
      } else if (filter.isNotEmpty &&
          r.toJson()[repository.kind == EntityKind.publishers
                  ? 'city'
                  : 'country'] !=
              filter) {
        return false;
      }
      return true;
    }).toList();
    rows.sort((a, b) {
      final left = sort == 'label' ? a.label : a.toJson()[sort] ?? a.label;
      final right = sort == 'label' ? b.label : b.toJson()[sort] ?? b.label;
      final result = left is num && right is num
          ? left.compareTo(right)
          : left.toString().toLowerCase().compareTo(
              right.toString().toLowerCase(),
            );
      final stable = result == 0 ? a.id.compareTo(b.id) : result;
      return ascending ? stable : -stable;
    });
    final total = rows.length;
    final pages = total == 0 ? 1 : (total / size).ceil();
    final current = page.clamp(1, pages);
    rows = rows.skip((current - 1) * size).take(size).toList();
    return PageResult(items: rows, page: current, size: size, total: total);
  }
}
