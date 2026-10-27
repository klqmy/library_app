import 'package:flutter/foundation.dart';
import '../models/author.dart';
import '../models/page_result.dart';
import '../repositories/author_repository.dart';

enum AuthorLoadStatus { idle, loading, success, error }

class AuthorListNotifier extends ChangeNotifier {
  final AuthorRepository _repository;

  AuthorListNotifier(this._repository);

  String _search = '';
  String? _country;
  String _sortField = 'lastName';
  bool _sortAscending = true;
  int _page = 1;
  int _size = 10;
  bool _includeDeleted = false;

  PageResult<Author> _result = PageResult.empty();
  AuthorLoadStatus _status = AuthorLoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};

  String get search => _search;
  String? get country => _country;
  String get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  int get page => _page;
  int get size => _size;
  bool get includeDeleted => _includeDeleted;
  PageResult<Author> get result => _result;
  AuthorLoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    _status = AuthorLoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _result = await _repository.find(
        search: _search,
        country: _country,
        sortField: _sortField,
        sortAscending: _sortAscending,
        page: _page,
        size: _size,
        includeDeleted: _includeDeleted,
      );
      _status = AuthorLoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = AuthorLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> setSearch(String value) async {
    _search = value;
    _page = 1;
    await load();
  }

  Future<void> setCountry(String? value) async {
    _country = value;
    _page = 1;
    await load();
  }

  Future<void> setSort(String field) async {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }
    _page = 1;
    await load();
  }

  Future<void> setPage(int value) async {
    _page = value;
    await load();
  }

  Future<void> setSize(int value) async {
    _size = value;
    _page = 1;
    await load();
  }

  Future<void> toggleIncludeDeleted() async {
    _includeDeleted = !_includeDeleted;
    _page = 1;
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }
}