import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/library_service.dart';
import '../widgets/app_page.dart';
import '../widgets/request_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<Map<String, int>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<LibraryService>().statistics();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Статистика библиотеки',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Статистика библиотеки',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        FutureBuilder<Map<String, int>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return RequestState(
                error: snapshot.error,
                retry: () => setState(_load),
              );
            }
            const labels = {
              'books': 'Книги',
              'authors': 'Авторы',
              'genres': 'Жанры',
              'publishers': 'Издательства',
              'readers': 'Читатели',
              'users': 'Пользователи',
              'activeLoans': 'Открытые выдачи',
              'overdueLoans': 'Просроченные выдачи',
              'copiesAvailable': 'Свободные экземпляры',
            };
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final entry in labels.entries)
                  SizedBox(
                    width: 250,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${snapshot.data![entry.key] ?? 0}',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(entry.value),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
