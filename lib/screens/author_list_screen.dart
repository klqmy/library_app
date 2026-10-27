import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../state/author_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/entity_card_list.dart';
import '../models/author.dart';

class AuthorListScreen extends StatefulWidget {
  const AuthorListScreen({super.key});

  @override
  State<AuthorListScreen> createState() => _AuthorListScreenState();
}

class _AuthorListScreenState extends State<AuthorListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<AuthorListNotifier>().setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AuthorListNotifier>();
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторы'),
        leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/')),
        actions: [
          if (notifier.hasSelection)
            TextButton.icon(
              icon: const Icon(Icons.delete),
              label: Text('Удалить (${notifier.selected.length})'),
              onPressed: () => _confirmDeleteSelected(notifier),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Поиск по фамилии или стране',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _buildBody(notifier, isWide),
          ),
          _buildPagination(notifier),
        ],
      ),
    );
  }

  Widget _buildBody(AuthorListNotifier notifier, bool isWide) {
    if (notifier.status == AuthorLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifier.status == AuthorLoadStatus.error) {
      return Center(child: Text('Ошибка: ${notifier.error}'));
    }
    if (notifier.result.items.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }

    if (isWide) {
      return EntityTable<Author>(
        items: notifier.result.items,
        idOf: (a) => a.id,
        selected: notifier.selected,
        onToggleSelect: notifier.toggleSelection,
        sortField: notifier.sortField,
        sortAscending: notifier.sortAscending,
        onSort: notifier.setSort,
        columns: [
          TableColumnSpec(
              label: 'Фамилия',
              sortField: 'lastName',
              build: (a) => Text(a.lastName)),
          TableColumnSpec(
              label: 'Имя',
              sortField: 'firstName',
              build: (a) => Text(a.firstName)),
          TableColumnSpec(
              label: 'Страна',
              sortField: 'country',
              build: (a) => Text(a.country)),
        ],
        actions: (a) => [
          IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => context.go('/authors/${a.id}')),
          IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => notifier.softDelete(a.id)),
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntityCardList<Author>(
            items: notifier.result.items,
            idOf: (a) => a.id,
            selected: notifier.selected,
            onToggleSelect: notifier.toggleSelection,
            itemBuilder: (a) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(a.country),
              ],
            ),
            actions: (a) => [
              IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () => context.go('/authors/${a.id}')),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildPagination(AuthorListNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: notifier.result.hasPrevious
                ? () => notifier.setPage(notifier.page - 1)
                : null,
          ),
          Text('Стр. ${notifier.page} из ${notifier.result.totalPages}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: notifier.result.hasNext
                ? () => notifier.setPage(notifier.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSelected(AuthorListNotifier notifier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить выбранные?'),
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
    if (confirm == true) await notifier.deleteSelected();
  }
}