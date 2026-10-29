import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/book.dart';
import '../models/reader.dart';
import '../repositories/catalog_store.dart';
import '../repositories/catalog_repository.dart';
import '../validation/validators.dart';
import '../widgets/app_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/entity_card_list.dart';

Future<void> showProblem(BuildContext context, Object error) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Операция не выполнена'),
        content: Text(error.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );

Future<bool> confirmDelete(
  BuildContext context, {
  bool hard = false,
  int count = 1,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(hard ? 'Удалить навсегда?' : 'Переместить в корзину?'),
        content: Text(
          hard
              ? 'Будет окончательно удалено записей: $count. Восстановление невозможно.'
              : 'Записей: $count. Их можно будет восстановить из корзины.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;

String rowDescription(CatalogEntity row, CatalogRepository repo) {
  if (row is Book) {
    final publisher =
        repo.store.byId(EntityKind.publishers, row.publisherId)?.label ??
        'Издательство не найдено';
    return '${row.year} г. · $publisher · доступно ${row.copiesAvailable}/${row.copiesTotal}';
  }
  if (row is Reader) return '${row.email} · ${row.libraryCard.number}';
  if (repo.kind == EntityKind.genres) {
    return 'Связанных книг: ${repo.references(row.id)}';
  }
  return '${row.toJson()['country'] ?? ''}${row.toJson()['city'] == null ? '' : ' · ${row.toJson()['city']}'}';
}

class CatalogListScreen extends StatefulWidget {
  final EntityKind kind;
  final Uri uri;
  const CatalogListScreen({super.key, required this.kind, required this.uri});
  @override
  State<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends State<CatalogListScreen> {
  late final TextEditingController _search;
  late final TextEditingController _from;
  late final TextEditingController _to;
  final _selected = <int>{};
  Timer? _debounce;
  CatalogQuery get query => CatalogQuery(widget.uri);
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: query.search);
    _from = TextEditingController(text: query.params['yearFrom']);
    _to = TextEditingController(text: query.params['yearTo']);
  }

  @override
  void didUpdateWidget(covariant CatalogListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _selected.clear();
      if (_search.text != query.search) _search.text = query.search;
      if (_from.text != (query.params['yearFrom'] ?? '')) {
        _from.text = query.params['yearFrom'] ?? '';
      }
      if (_to.text != (query.params['yearTo'] ?? '')) {
        _to.text = query.params['yearTo'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _set(Map<String, String?> changes, {bool resetPage = true}) {
    final params = Map<String, String>.from(widget.uri.queryParameters);
    if (resetPage) params['page'] = '1';
    for (final entry in changes.entries) {
      if (entry.value == null || entry.value!.isEmpty) {
        params.remove(entry.key);
      } else {
        params[entry.key] = entry.value!;
      }
    }
    context.go(
      Uri(
        path: widget.kind.path,
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _set({'search': value});
    });
  }

  void _toggle(int id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );
  Future<void> _delete(
    CatalogRepository repo,
    Set<int> ids, {
    bool hard = false,
  }) async {
    if (!await confirmDelete(context, hard: hard, count: ids.length)) return;
    try {
      await repo.deleteMany(ids, hard: hard);
      if (!mounted) return;
      setState(_selected.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hard ? 'Записи удалены' : 'Записи в корзине')),
      );
    } catch (e) {
      if (mounted) await showProblem(context, e);
    }
  }

  Future<void> _action(
    String action,
    CatalogEntity row,
    CatalogRepository repo,
  ) async {
    if (action == 'edit') {
      context.go('${widget.kind.path}/${row.id}/edit');
      return;
    }
    if (action == 'restore') {
      try {
        await repo.restore(row.id);
      } catch (e) {
        if (mounted) await showProblem(context, e);
      }
    } else {
      await _delete(repo, {row.id}, hard: action == 'hard');
    }
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 205,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${items.keys.join()}'),
      initialValue: items.containsKey(value) ? value : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogStore>();
    final repo = CatalogRepository(store, widget.kind);
    final result = query.find(repo);
    final countries = {
      ...repo.all.map((r) => r.toJson()['country']).whereType<String>(),
    }.toList()..sort();
    final filters = switch (widget.kind) {
      EntityKind.books => {
        '': 'Любая доступность',
        'available': 'Есть в наличии',
        'unavailable': 'Нет в наличии',
      },
      EntityKind.authors || EntityKind.publishers => {
        '': 'Все страны',
        for (final c in countries) c: c,
      },
      EntityKind.genres => {
        '': 'Все жанры',
        'linked': 'Есть книги',
        'empty': 'Без книг',
      },
      EntityKind.readers => {
        '': 'Все билеты',
        'valid': 'Действующие',
        'expired': 'Истёкшие',
      },
    };
    final sortFields = {
      'label': 'По названию / имени',
      'id': 'По ID',
      if (widget.kind == EntityKind.books) ...{
        'year': 'По году',
        'pages': 'По страницам',
        'copiesAvailable': 'По наличию',
      },
      if (widget.kind == EntityKind.authors ||
          widget.kind == EntityKind.publishers)
        'country': 'По стране',
      if (widget.kind == EntityKind.readers) 'email': 'По почте',
    };
    List<Widget> actions(CatalogEntity row) => [
      IconButton(
        tooltip: 'Открыть карточку',
        icon: const Icon(Icons.open_in_new, size: 20),
        onPressed: () => context.go('${widget.kind.path}/${row.id}'),
      ),
      PopupMenuButton<String>(
        tooltip: 'Действия с записью',
        onSelected: (v) => _action(v, row, repo),
        itemBuilder: (c) => [
          const PopupMenuItem(value: 'edit', child: Text('Изменить')),
          if (row.isDeleted)
            const PopupMenuItem(value: 'restore', child: Text('Восстановить')),
          if (!row.isDeleted)
            const PopupMenuItem(value: 'soft', child: Text('В корзину')),
          const PopupMenuItem(value: 'hard', child: Text('Удалить навсегда')),
        ],
      ),
    ];
    return AppPage(
      title: widget.kind.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Text(
                widget.kind.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              FilledButton.icon(
                onPressed: () => context.go('${widget.kind.path}/new'),
                icon: const Icon(Icons.add),
                label: const Text('Создать запись'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            onChanged: _searchChanged,
            decoration: InputDecoration(
              labelText: 'Поиск',
              hintText: 'Название, имя или другое поле',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Очистить поиск',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  _set({'search': null});
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dropdown('Статус', query.status, {
                'active': 'Активные',
                'deleted': 'Корзина',
                'all': 'Все записи',
              }, (v) => _set({'status': v})),
              _dropdown(
                widget.kind == EntityKind.authors ||
                        widget.kind == EntityKind.publishers
                    ? 'Страна'
                    : 'Фильтр',
                query.filter,
                filters,
                (v) => _set({'filter': v}),
              ),
              if (widget.kind == EntityKind.books) ...[
                _dropdown(
                  'Издательство',
                  query.params['publisherId'] ?? '',
                  {
                    '': 'Все издательства',
                    for (final p in repo.options(EntityKind.publishers))
                      '${p.id}': p.label,
                  },
                  (v) => _set({'publisherId': v}),
                ),
                _dropdown('Жанр', query.params['genreId'] ?? '', {
                  '': 'Все жанры',
                  for (final g in repo.options(EntityKind.genres))
                    '${g.id}': g.label,
                }, (v) => _set({'genreId': v})),
                for (final entry in [
                  ('yearFrom', 'Год от', _from),
                  ('yearTo', 'Год до', _to),
                ])
                  SizedBox(
                    width: 135,
                    child: TextFormField(
                      controller: entry.$3,
                      keyboardType: TextInputType.number,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => (v ?? '').isEmpty
                          ? null
                          : Validators.integer(
                              v,
                              min: 1450,
                              max: DateTime.now().year + 1,
                            ),
                      decoration: InputDecoration(labelText: entry.$2),
                      onChanged: (v) {
                        if (v.isEmpty ||
                            Validators.integer(
                                  v,
                                  min: 1450,
                                  max: DateTime.now().year + 1,
                                ) ==
                                null) {
                          _set({entry.$1: v});
                        }
                      },
                    ),
                  ),
              ],
              _dropdown(
                'Сортировка',
                query.sort,
                sortFields,
                (v) => _set({'sort': '$v,${query.ascending ? 'asc' : 'desc'}'}),
              ),
              IconButton(
                tooltip: 'Изменить направление сортировки',
                onPressed: () => _set({
                  'sort': '${query.sort},${query.ascending ? 'desc' : 'asc'}',
                }),
                icon: Icon(
                  query.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
              ),
              OutlinedButton(
                onPressed: () => context.go(widget.kind.path),
                child: const Text('Сбросить фильтры'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Найдено: ${result.total} · Выбрано: ${_selected.length}'),
              TextButton(
                onPressed: () => setState(() {
                  _selected.addAll(result.items.map((r) => r.id));
                }),
                child: const Text('Выбрать страницу'),
              ),
              if (_selected.isNotEmpty) ...[
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Снять выбор'),
                ),
                OutlinedButton(
                  onPressed: () => _delete(repo, Set.from(_selected)),
                  child: const Text('В корзину'),
                ),
                TextButton(
                  onPressed: () =>
                      _delete(repo, Set.from(_selected), hard: true),
                  child: const Text('Удалить навсегда'),
                ),
              ],
              IconButton(
                tooltip: 'Таблица',
                icon: const Icon(Icons.table_rows_outlined),
                onPressed: () => _set({'view': 'table'}, resetPage: false),
              ),
              IconButton(
                tooltip: 'Карточки',
                icon: const Icon(Icons.grid_view),
                onPressed: () => _set({'view': 'cards'}, resetPage: false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (result.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'Записи не найдены. Измените фильтры или создайте запись.',
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (c, constraints) {
                if (constraints.maxWidth < 800 ||
                    query.params['view'] == 'cards') {
                  return EntityCardList<CatalogEntity>(
                    items: result.items,
                    idOf: (r) => r.id,
                    selected: _selected,
                    onToggleSelect: _toggle,
                    actions: actions,
                    itemBuilder: (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${r.isDeleted ? 'В корзине · ' : ''}${rowDescription(r, repo)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return Card(
                  child: EntityTable<CatalogEntity>(
                    items: result.items,
                    idOf: (r) => r.id,
                    selected: _selected,
                    onToggleSelect: _toggle,
                    sortField: query.sort,
                    sortAscending: query.ascending,
                    onSort: (field) => _set({
                      'sort':
                          '$field,${query.sort == field && query.ascending ? 'desc' : 'asc'}',
                    }),
                    columns: [
                      TableColumnSpec(
                        label: 'ID',
                        sortField: 'id',
                        build: (r) => Text('${r.id}'),
                      ),
                      TableColumnSpec(
                        label: 'Название / имя',
                        sortField: 'label',
                        build: (r) => SizedBox(
                          width: 285,
                          child: InkWell(
                            onTap: () =>
                                context.go('${widget.kind.path}/${r.id}'),
                            child: Text(
                              r.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      TableColumnSpec(
                        label: 'Сведения',
                        build: (r) => SizedBox(
                          width: 340,
                          child: Text(
                            rowDescription(r, repo),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      TableColumnSpec(
                        label: 'Статус',
                        build: (r) =>
                            Text(r.isDeleted ? 'В корзине' : 'Активна'),
                      ),
                    ],
                    actions: actions,
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: result.hasPrevious
                    ? () =>
                          _set({'page': '${result.page - 1}'}, resetPage: false)
                    : null,
                child: const Text('Назад'),
              ),
              Text('Страница ${result.page} из ${result.totalPages}'),
              OutlinedButton(
                onPressed: result.hasNext
                    ? () =>
                          _set({'page': '${result.page + 1}'}, resetPage: false)
                    : null,
                child: const Text('Вперёд'),
              ),
              _dropdown('Записей на странице', '${query.size}', {
                '5': '5',
                '10': '10',
                '20': '20',
              }, (v) => _set({'size': v})),
            ],
          ),
        ],
      ),
    );
  }
}
