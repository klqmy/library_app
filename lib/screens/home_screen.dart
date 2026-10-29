import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../repositories/catalog_store.dart';
import '../widgets/app_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogStore>();
    return AppPage(
      title: 'Библиотечная система',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Библиотека', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'Каталог, справочники и читательские билеты',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final kind in EntityKind.values)
                SizedBox(
                  width: 290,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go(kind.path),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              iconFor(kind),
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              kind.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Записей: ${store.all(kind).where((r) => !r.isDeleted).length}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Данные сохраняются в этом браузере. Для продолжения работы открывайте приложение по тому же адресу.',
          ),
        ],
      ),
    );
  }
}
