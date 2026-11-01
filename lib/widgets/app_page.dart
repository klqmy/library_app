import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../state/auth_notifier.dart';
import '../state/permissions.dart';

IconData iconFor(EntityKind kind) => switch (kind) {
  EntityKind.books => Icons.menu_book,
  EntityKind.authors => Icons.edit_note,
  EntityKind.genres => Icons.category_outlined,
  EntityKind.publishers => Icons.business,
  EntityKind.readers => Icons.badge_outlined,
};

typedef _Destination = ({String label, String path, IconData icon});

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final String? backPath;
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.backPath,
  });

  List<_Destination> _destinations(AuthNotifier auth) => [
    (label: 'Главная', path: '/', icon: Icons.home_outlined),
    for (final kind in EntityKind.values)
      if (kind != EntityKind.readers || auth.can(Operation.manageReaders))
        (label: kind.title, path: kind.path, icon: iconFor(kind)),
    if (auth.can(Operation.ownLoans))
      (label: 'Мои выдачи', path: '/my-loans', icon: Icons.badge_outlined),
    if (auth.can(Operation.loanDesk))
      (label: 'Рабочее место', path: '/loans', icon: Icons.assignment_outlined),
    if (auth.can(Operation.manageUsers))
      (label: 'Пользователи', path: '/admin/users', icon: Icons.people_outline),
    if (auth.can(Operation.statistics))
      (label: 'Статистика', path: '/admin/stats', icon: Icons.bar_chart),
  ];

  Future<void> _showMenu(BuildContext context, List<_Destination> entries) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in entries)
                  ListTile(
                    leading: Icon(entry.icon),
                    title: Text(entry.label),
                    onTap: () {
                      Navigator.pop(sheet);
                      context.go(entry.path);
                    },
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final entries = _destinations(auth);
    final path =
        GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ??
        '/';
    final current = entries.indexWhere(
      (e) => e.path == '/'
          ? path == '/'
          : path == e.path || path.startsWith('${e.path}/'),
    );
    final primary = auth.can(Operation.manageUsers)
        ? (label: 'Роли', path: '/admin/users', icon: Icons.people_outline)
        : auth.can(Operation.loanDesk)
        ? (label: 'Выдачи', path: '/loans', icon: Icons.assignment_outlined)
        : (label: 'Выдачи', path: '/my-loans', icon: Icons.badge_outlined);
    final bottomIndex = path == '/'
        ? 0
        : path.startsWith(primary.path)
        ? 2
        : [
            '/books',
            '/authors',
            '/genres',
            '/publishers',
          ].any((p) => path == p || path.startsWith('$p/'))
        ? 1
        : 3;
    final content = SingleChildScrollView(
      key: const PageStorageKey('page-content'),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.warningSeconds != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Сессия завершится через ${auth.warningSeconds} с без действий.',
                      ),
                      TextButton(
                        onPressed: auth.activity,
                        child: const Text('Продолжить работу'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: backPath == null ? 'Главная' : 'Назад',
          icon: Icon(
            backPath == null ? Icons.local_library_outlined : Icons.arrow_back,
          ),
          onPressed: () => context.go(backPath ?? '/'),
        ),
        actions: [
          ...actions,
          if (width >= 1000)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  '${auth.user?.fullName ?? ''} · ${auth.uiRole.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Выйти из системы',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!mobile) ...[
                  NavigationRail(
                    scrollable: true,
                    extended: width >= 1100,
                    minExtendedWidth: 220,
                    selectedIndex: current < 0 ? 0 : current,
                    labelType: width >= 1100
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.selected,
                    onDestinationSelected: (i) => context.go(entries[i].path),
                    destinations: [
                      for (final entry in entries)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: entry.label,
                            child: Icon(entry.icon),
                          ),
                          label: Text(entry.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: mobile
          ? NavigationBar(
              selectedIndex: bottomIndex,
              onDestinationSelected: (i) {
                if (i == 3) {
                  _showMenu(context, entries);
                } else {
                  context.go(['/', '/books', primary.path][i]);
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Главная',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu_book),
                  label: 'Каталог',
                ),
                NavigationDestination(
                  icon: Icon(primary.icon),
                  label: primary.label,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu),
                  label: 'Ещё',
                ),
              ],
            )
          : null,
    );
  }
}
