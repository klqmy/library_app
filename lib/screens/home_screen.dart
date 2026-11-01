import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';
import '../state/permissions.dart';
import '../widgets/app_page.dart';
import '../widgets/responsive_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final links = [
      (
        'Каталог',
        'Книги, авторы, жанры и издательства',
        '/books',
        Icons.menu_book,
      ),
      if (auth.can(Operation.ownLoans))
        (
          'Мои выдачи',
          'Ваши книги, сроки и продление',
          '/my-loans',
          Icons.badge_outlined,
        ),
      if (auth.can(Operation.loanDesk))
        (
          'Рабочее место библиотекаря',
          'Выдача и возврат книг',
          '/loans',
          Icons.assignment_outlined,
        ),
      if (auth.can(Operation.manageReaders))
        (
          'Читатели',
          'Учётные записи и читательские билеты',
          '/readers',
          Icons.people_outline,
        ),
      if (auth.can(Operation.manageUsers))
        (
          'Пользователи и роли',
          'Управление доступом к системе',
          '/admin/users',
          Icons.admin_panel_settings_outlined,
        ),
      if (auth.can(Operation.statistics))
        (
          'Статистика',
          'Сведения о каталоге и выдачах',
          '/admin/stats',
          Icons.bar_chart,
        ),
    ];
    return AppPage(
      title: 'Библиотечная система',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Здравствуйте, ${auth.user?.fullName ?? ''}!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Chip(label: Text(auth.uiRole.label)),
          const SizedBox(height: 22),
          ResponsiveGrid(
            children: [
              for (final item in links)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$4, size: 32),
                        const SizedBox(height: 18),
                        Text(
                          item.$1,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(item.$2),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                          onPressed: () => context.go(item.$3),
                          child: const Text('Открыть'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
