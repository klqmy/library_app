import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/entity_kind.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_list_screen.dart';
import 'screens/entity_detail_screen.dart';
import 'screens/entity_form_screen.dart';
import 'screens/not_found_screen.dart';
import 'state/form_guard.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
    for (final kind in EntityKind.values) ...[
      GoRoute(
        path: kind.path,
        builder: (c, s) =>
            CatalogListScreen(key: s.pageKey, kind: kind, uri: s.uri),
      ),
      GoRoute(
        path: '${kind.path}/new',
        builder: (c, s) => EntityFormScreen(key: s.pageKey, kind: kind),
        onExit: (c, s) => c.read<FormGuard>().canLeave(c),
      ),
      GoRoute(
        path: '${kind.path}/:id/edit',
        builder: (c, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? NotFoundScreen(location: s.uri.toString())
              : EntityFormScreen(key: s.pageKey, kind: kind, id: id);
        },
        onExit: (c, s) => c.read<FormGuard>().canLeave(c),
      ),
      GoRoute(
        path: '${kind.path}/:id',
        builder: (c, s) => EntityDetailScreen(
          kind: kind,
          id: int.tryParse(s.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
    ],
  ],
  errorBuilder: (c, s) => NotFoundScreen(location: s.uri.toString()),
);
