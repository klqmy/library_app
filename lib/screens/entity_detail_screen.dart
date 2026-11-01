import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../models/reader.dart';
import '../models/json_values.dart';
import '../forms/field_spec.dart';
import '../repositories/catalog_store.dart';
import '../repositories/catalog_repository.dart';
import '../widgets/app_page.dart';
import '../widgets/loan_dialog.dart';
import 'not_found_screen.dart';
import 'catalog_list_screen.dart';

class EntityDetailScreen extends StatelessWidget {
  final EntityKind kind;
  final int id;
  const EntityDetailScreen({super.key, required this.kind, required this.id});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogStore>();
    final repo = CatalogRepository(store, kind);
    final row = repo.byId(id);
    if (row == null) return NotFoundScreen(location: '${kind.path}/$id');
    final values = formData(row);
    final books = store.relatedBooks(kind, id);
    return AppPage(
      title: kind.singular,
      backPath: kind.path,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(row.label, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('ID: $id · ${row.isDeleted ? 'В корзине' : 'Активная запись'}'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!row.isDeleted)
                FilledButton.icon(
                  onPressed: () => context.go('${kind.path}/$id/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать'),
                ),
              if (kind == EntityKind.books && !row.isDeleted)
                OutlinedButton.icon(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => LoanDialog(repository: repo, bookId: id),
                  ),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Выдать книгу'),
                ),
              if (row.isDeleted)
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await repo.restore(id);
                      if (context.mounted) context.go(kind.path);
                    } catch (e) {
                      if (context.mounted) await showProblem(context, e);
                    }
                  },
                  child: const Text('Восстановить'),
                ),
              OutlinedButton(
                onPressed: () async {
                  if (!await confirmDelete(context, hard: row.isDeleted)) {
                    return;
                  }
                  try {
                    await repo.deleteMany({id}, hard: row.isDeleted);
                    if (context.mounted) context.go(kind.path);
                  } catch (e) {
                    if (context.mounted) await showProblem(context, e);
                  }
                },
                child: Text(row.isDeleted ? 'Удалить навсегда' : 'В корзину'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in fieldsFor(kind)) ...[
                    if (field.name == 'card.number') ...[
                      const SizedBox(height: 12),
                      Text(
                        'Читательский билет',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (row as Reader).card == null
                            ? 'Билет не оформлен'
                            : 'ID билета: ${row.card!.id}',
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          if (field.relation != null)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final relatedId
                                    in field.type == FieldType.multi
                                        ? jsonIds(values[field.name])
                                        : [jsonInt(values[field.name])])
                                  ActionChip(
                                    label: Text(
                                      store
                                              .byId(field.relation!, relatedId)
                                              ?.label ??
                                          'Нет записи #$relatedId',
                                    ),
                                    onPressed: () => context.go(
                                      '${field.relation!.path}/$relatedId',
                                    ),
                                  ),
                              ],
                            )
                          else
                            SelectableText(
                              '${values[field.name] ?? ''}'.isEmpty
                                  ? 'Не указано'
                                  : '${values[field.name]}',
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (kind == EntityKind.authors ||
              kind == EntityKind.genres ||
              kind == EntityKind.publishers) ...[
            const SizedBox(height: 24),
            Text(
              'Связанные книги (${books.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (books.isEmpty) const Text('Связанных книг пока нет.'),
            for (final book in books)
              Card(
                child: ListTile(
                  title: Text(book.title),
                  subtitle: Text(
                    '${book.year} г.${book.isDeleted ? ' · В корзине' : ''}',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => context.go('/books/${book.id}'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
