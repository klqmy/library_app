import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_page.dart';

class NotFoundScreen extends StatelessWidget {
  final String location;
  const NotFoundScreen({super.key, required this.location});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Страница не найдена',
    child: Column(
      children: [
        const Text('404', style: TextStyle(fontSize: 64)),
        Text('Адрес или запись не найдены: $location'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('На главную'),
        ),
      ],
    ),
  );
}
