import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/entity_kind.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_list_screen.dart';
import 'screens/entity_detail_screen.dart';
import 'screens/entity_form_screen.dart';
import 'screens/not_found_screen.dart';
import 'state/form_guard.dart';
import 'widgets/entity_loader.dart';
import 'package:flutter/widgets.dart';

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
        builder: (c, s) => EntityLoader(
          key: ValueKey('${kind.name}:new'),
          kind: kind,
          builder: (_) => EntityFormScreen(kind: kind),
        ),
        onExit: (c, s) => c.read<FormGuard>().canLeave(c),
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
        onExit: (c, s) => c.read<FormGuard>().canLeave(c),
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
