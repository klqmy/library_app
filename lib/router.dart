import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/entity_kind.dart';
import 'screens/auth_screen.dart';
import 'screens/forbidden_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/users_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/catalog_list_screen.dart';
import 'screens/entity_detail_screen.dart';
import 'screens/entity_form_screen.dart';
import 'screens/not_found_screen.dart';
import 'state/auth_notifier.dart';
import 'state/form_guard.dart';
import 'state/permissions.dart';
import 'widgets/entity_loader.dart';

Operation? requiredOperation(String path) {
  if (path == '/my-loans') return Operation.ownLoans;
  if (path == '/loans') return Operation.loanDesk;
  if (path == '/admin/users') return Operation.manageUsers;
  if (path == '/admin/stats') return Operation.statistics;
  if (path == '/readers' || path.startsWith('/readers/')) {
    return Operation.manageReaders;
  }
  if (RegExp(
    r'^/(books|authors|genres|publishers)/(new|[^/]+/edit)$',
  ).hasMatch(path)) {
    return Operation.manageCatalog;
  }
  return null;
}

GoRouter buildRouter(AuthNotifier auth) => GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    final path = state.uri.path;
    final public = path == '/login' || path == '/register';
    if (!auth.isAuthenticated && !public) {
      return Uri(
        path: '/login',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (auth.isAuthenticated && public) {
      return safeDestination(state.uri.queryParameters['from']);
    }
    final operation = requiredOperation(path);
    if (auth.isAuthenticated && operation != null && !auth.can(operation)) {
      return Uri(
        path: '/forbidden',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (c, s) => AuthScreen(from: s.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/register',
      builder: (c, s) =>
          AuthScreen(register: true, from: s.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/forbidden',
      builder: (c, s) =>
          ForbiddenScreen(location: s.uri.queryParameters['from']),
    ),
    GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
    GoRoute(
      path: '/my-loans',
      builder: (c, s) =>
          const LoansScreen(key: ValueKey('own-loans'), own: true),
    ),
    GoRoute(
      path: '/loans',
      builder: (c, s) =>
          const LoansScreen(key: ValueKey('loan-desk'), own: false),
    ),
    GoRoute(path: '/admin/users', builder: (c, s) => const UsersScreen()),
    GoRoute(path: '/admin/stats', builder: (c, s) => const StatisticsScreen()),
    for (final kind in EntityKind.values) ...[
      GoRoute(
        path: kind.path,
        builder: (c, s) =>
            CatalogListScreen(key: s.pageKey, kind: kind, uri: s.uri),
      ),
      GoRoute(
        path: '${kind.path}/new',
        builder: (c, s) => EntityLoader(
          key: ValueKey('${kind.name}:new'),
          kind: kind,
          builder: (_) => EntityFormScreen(kind: kind),
        ),
        onExit: (c, s) async =>
            !auth.isAuthenticated || await c.read<FormGuard>().canLeave(c),
      ),
      GoRoute(
        path: '${kind.path}/:id/edit',
        builder: (c, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? NotFoundScreen(location: s.uri.toString())
              : EntityLoader(
                  key: ValueKey('${kind.name}:$id:edit'),
                  kind: kind,
                  id: id,
                  builder: (_) => EntityFormScreen(kind: kind, id: id),
                );
        },
        onExit: (c, s) async =>
            !auth.isAuthenticated || await c.read<FormGuard>().canLeave(c),
      ),
      GoRoute(
        path: '${kind.path}/:id',
        builder: (c, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '') ?? -1;
          return EntityLoader(
            key: ValueKey('${kind.name}:$id'),
            kind: kind,
            id: id,
            detail: true,
            builder: (_) => EntityDetailScreen(kind: kind, id: id),
          );
        },
      ),
    ],
  ],
  errorBuilder: (c, s) => NotFoundScreen(location: s.uri.toString()),
);
