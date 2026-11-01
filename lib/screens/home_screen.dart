import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../repositories/catalog_store.dart';
import '../widgets/app_page.dart';
import '../widgets/request_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<void> _summary;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summary = context.read<CatalogStore>().summary();
  }

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
          FutureBuilder<void>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  snapshot.hasError) {
                return RequestState(
                  error: snapshot.error,
                  retry: () => setState(_load),
                );
              }
              return Wrap(
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
                                Text('Записей: ${store.totals[kind] ?? 0}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Данные загружаются с учебного сервера.'),
        ],
      ),
    );
  }
}
