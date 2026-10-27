import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../state/book_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/entity_card_list.dart';
import '../models/book.dart';
import '../models/book_query.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uri = GoRouterState.of(context).uri;
    final q = uri.queryParameters;

    final notifier = context.read<BookListNotifier>();

    final newSearch = q['search'] ?? '';
    final newGenreId =
        q['genreId'] != null ? int.tryParse(q['genreId']!) : null;
    final newPublisherId = q['publisherId'] != null
        ? int.tryParse(q['publisherId']!)
        : null;
    final newYearFrom =
        q['yearFrom'] != null ? int.tryParse(q['yearFrom']!) : null;
    final newYearTo =
        q['yearTo'] != null ? int.tryParse(q['yearTo']!) : null;
    final newSortField = q['sort']?.split(',').first ?? 'title';
    final newSortAscending = q['sort']?.split(',').last != 'desc';
    final newPage =
        q['page'] != null ? (int.tryParse(q['page']!) ?? 1) : 1;
    final newSize =
        q['size'] != null ? (int.tryParse(q['size']!) ?? 10) : 10;
    final newIncludeDeleted = q['deleted'] == '1';

    if (_searchController.text != newSearch) {
      _searchController.text = newSearch;
    }

    final needsUpdate = notifier.query.search != newSearch ||
        notifier.query.genreId != newGenreId ||
        notifier.query.publisherId != newPublisherId ||
        notifier.query.yearFrom != newYearFrom ||
        notifier.query.yearTo != newYearTo ||
        notifier.query.sortField != newSortField ||
        notifier.query.sortAscending != newSortAscending ||
        notifier.query.page != newPage ||
        notifier.query.size != newSize ||
        notifier.query.includeDeleted != newIncludeDeleted;

    if (needsUpdate) {
      notifier.applyQuery(BookQuery(
        search: newSearch,
        genreId: newGenreId,
        publisherId: newPublisherId,
        yearFrom: newYearFrom,
        yearTo: newYearTo,
        sortField: newSortField,
        sortAscending: newSortAscending,
        page: newPage,
        size: newSize,
        includeDeleted: newIncludeDeleted,
      ));
    }
  }

  void _syncUrl(BookListNotifier notifier) {
    final q = notifier.query;
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.genreId != null) params['genreId'] = '${q.genreId}';
    if (q.publisherId != null) params['publisherId'] = '${q.publisherId}';
    if (q.yearFrom != null) params['yearFrom'] = '${q.yearFrom}';
    if (q.yearTo != null) params['yearTo'] = '${q.yearTo}';
    params['sort'] =
        '${q.sortField},${q.sortAscending ? "asc" : "desc"}';
    params['page'] = '${q.page}';
    params['size'] = '${q.size}';
    if (q.includeDeleted) params['deleted'] = '1';

    context.go('/books?${Uri(queryParameters: params).query}');
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final notifier = context.read<BookListNotifier>();
      notifier.applyQuery(notifier.query.copyWith(search: value));
      _syncUrl(notifier);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<BookListNotifier>();
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог книг'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (notifier.hasSelection)
            TextButton.icon(
              icon: const Icon(Icons.delete),
              label: Text('Удалить (${notifier.selected.length})'),
              onPressed: () => _confirmDeleteSelected(notifier),
            ),
          IconButton(
            icon: Icon(notifier.query.includeDeleted
                ? Icons.visibility_off
                : Icons.visibility),
            tooltip: notifier.query.includeDeleted
                ? 'Скрыть удалённые'
                : 'Показать удалённые',
            onPressed: () {
              notifier.applyQuery(notifier.query.copyWith(
                  includeDeleted: !notifier.query.includeDeleted));
              _syncUrl(notifier);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Поиск по названию или ISBN',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: notifier.query.genreId,
                        decoration: const InputDecoration(
                          labelText: 'Жанр',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Все')),
                          DropdownMenuItem(value: 1, child: Text('Роман')),
                          DropdownMenuItem(value: 2, child: Text('Повесть')),
                          DropdownMenuItem(value: 3, child: Text('Детектив')),
                          DropdownMenuItem(value: 4, child: Text('Поэзия')),
                          DropdownMenuItem(value: 5, child: Text('Сатира')),
                          DropdownMenuItem(value: 6, child: Text('Драма')),
                          DropdownMenuItem(
                              value: 7, child: Text('Любовный')),
                          DropdownMenuItem(
                              value: 8,
                              child: Text('Магический реализм')),
                          DropdownMenuItem(
                              value: 9, child: Text('Приключения')),
                          DropdownMenuItem(
                              value: 10, child: Text('Абсурд')),
                          DropdownMenuItem(
                              value: 11, child: Text('Исторический')),
                        ],
                        onChanged: (v) {
                          notifier.applyQuery(
                              notifier.query.copyWith(genreId: v));
                          _syncUrl(notifier);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: notifier.query.publisherId,
                        decoration: const InputDecoration(
                          labelText: 'Издательство',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Все')),
                          DropdownMenuItem(value: 1, child: Text('Изд-во 1')),
                          DropdownMenuItem(value: 2, child: Text('Изд-во 2')),
                          DropdownMenuItem(value: 3, child: Text('Изд-во 3')),
                          DropdownMenuItem(value: 4, child: Text('Изд-во 4')),
                          DropdownMenuItem(value: 5, child: Text('Изд-во 5')),
                          DropdownMenuItem(value: 6, child: Text('Изд-во 6')),
                          DropdownMenuItem(value: 7, child: Text('Изд-во 7')),
                          DropdownMenuItem(value: 8, child: Text('Изд-во 8')),
                          DropdownMenuItem(value: 9, child: Text('Изд-во 9')),
                        ],
                        onChanged: (v) {
                          notifier.applyQuery(notifier.query.copyWith(
                              publisherId: v));
                          _syncUrl(notifier);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            notifier.query.yearFrom?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Год от',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (v) {
                          final y =
                              v.isEmpty ? null : int.tryParse(v);
                          notifier.applyQuery(
                              notifier.query.copyWith(yearFrom: y));
                          _syncUrl(notifier);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            notifier.query.yearTo?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Год до',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (v) {
                          final y =
                              v.isEmpty ? null : int.tryParse(v);
                          notifier.applyQuery(
                              notifier.query.copyWith(yearTo: y));
                          _syncUrl(notifier);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: notifier.query.size,
                      items: const [10, 25, 50]
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text('По $s')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          notifier.applyQuery(
                              notifier.query.copyWith(size: v));
                          _syncUrl(notifier);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(notifier, isWide)),
          _buildPagination(notifier),
        ],
      ),
    );
  }

  Widget _buildBody(BookListNotifier notifier, bool isWide) {
    if (notifier.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifier.status == LoadStatus.error) {
      return Center(child: Text('Ошибка: ${notifier.error}'));
    }
    if (notifier.result.items.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }

    if (isWide) {
      return EntityTable<Book>(
        items: notifier.result.items,
        idOf: (b) => b.id,
        selected: notifier.selected,
        onToggleSelect: notifier.toggleSelection,
        sortField: notifier.query.sortField,
        sortAscending: notifier.query.sortAscending,
        onSort: (field) {
          notifier.applyQuery(notifier.query.copyWith(
            sortField: field,
            sortAscending: field == notifier.query.sortField
                ? !notifier.query.sortAscending
                : true,
          ));
          _syncUrl(notifier);
        },
        columns: [
          TableColumnSpec(
            label: 'Название',
            sortField: 'title',
            build: (b) => Text(b.title),
          ),
          TableColumnSpec(
            label: 'Год',
            sortField: 'year',
            numeric: true,
            build: (b) => Text('${b.year}'),
          ),
          TableColumnSpec(
            label: 'Страниц',
            sortField: 'pages',
            numeric: true,
            build: (b) => Text('${b.pages}'),
          ),
        ],
        actions: (b) => [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () => context.go('/books/${b.id}'),
          ),
          IconButton(
            icon: Icon(b.isDeleted ? Icons.restore : Icons.delete),
            onPressed: () => b.isDeleted
                ? notifier.restore(b.id)
                : notifier.softDelete(b.id),
          ),
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntityCardList<Book>(
            items: notifier.result.items,
            idOf: (b) => b.id,
            selected: notifier.selected,
            onToggleSelect: notifier.toggleSelection,
            itemBuilder: (b) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                Text('Год: ${b.year}, Страниц: ${b.pages}'),
              ],
            ),
            actions: (b) => [
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => context.go('/books/${b.id}'),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildPagination(BookListNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: notifier.result.hasPrevious
                ? () {
                    notifier.applyQuery(
                        notifier.query.copyWith(page: 1));
                    _syncUrl(notifier);
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: notifier.result.hasPrevious
                ? () {
                    notifier.applyQuery(notifier.query.copyWith(
                        page: notifier.query.page - 1));
                    _syncUrl(notifier);
                  }
                : null,
          ),
          Text(
              'Стр. ${notifier.query.page} из ${notifier.result.totalPages} (всего: ${notifier.result.total})'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: notifier.result.hasNext
                ? () {
                    notifier.applyQuery(notifier.query.copyWith(
                        page: notifier.query.page + 1));
                    _syncUrl(notifier);
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: notifier.result.hasNext
                ? () {
                    notifier.applyQuery(notifier.query.copyWith(
                        page: notifier.result.totalPages));
                    _syncUrl(notifier);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSelected(BookListNotifier notifier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить выбранные?'),
        content: Text(
            'Будет удалено записей: ${notifier.selected.length}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await notifier.deleteSelected();
      _syncUrl(notifier);
    }
  }
}