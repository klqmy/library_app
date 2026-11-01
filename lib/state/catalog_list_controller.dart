import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/page_result.dart';
import '../repositories/catalog_repository.dart';

enum LoadStatus { loading, data, empty, error }

class CatalogListController extends ChangeNotifier {
  final CatalogRepository repository;
  CatalogListController(this.repository) {
    _revision = repository.store.revision;
    repository.store.addListener(_changed);
  }
  late int _revision;
  CatalogQuery? _query;
  RequestToken? _request;
  int _generation = 0;
  bool _disposed = false;
  LoadStatus status = LoadStatus.loading;
  PageResult<CatalogEntity> result = PageResult.empty();
  ApiException? error;

  void _changed() {
    if (_revision == repository.store.revision) return;
    _revision = repository.store.revision;
    if (_query != null) load(_query!);
  }

  Future<void> load(CatalogQuery query) async {
    _query = query;
    _request?.cancel();
    final request = _request = RequestToken();
    final generation = ++_generation;
    status = LoadStatus.loading;
    error = null;
    result = PageResult.empty();
    notifyListeners();
    try {
      final page = await repository.find(query, cancel: request);
      await repository.store.ensureReferences();
      if (_disposed || generation != _generation || request.isCancelled) return;
      result = page;
      repository.store.cachePage(repository.kind, page.items, page.total);
      status = page.items.isEmpty ? LoadStatus.empty : LoadStatus.data;
    } on RequestCancelledException {
      return;
    } on ApiException catch (e) {
      if (_disposed || generation != _generation) return;
      error = e;
      status = LoadStatus.error;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = const ServerException('Не удалось прочитать данные сервера.');
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void retry() {
    if (_query != null) load(_query!);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _request?.cancel();
    repository.store.removeListener(_changed);
    super.dispose();
  }
}
