import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_page.dart';

class ForbiddenScreen extends StatelessWidget {
  final String? location;
  const ForbiddenScreen({super.key, this.location});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Доступ запрещён',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 52),
          const SizedBox(height: 20),
          Text(
            'Доступ запрещён',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text('У вашей роли нет прав на этот раздел.'),
          if (location != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(location!),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('На главную'),
          ),
        ],
      ),
    ),
  );
}
