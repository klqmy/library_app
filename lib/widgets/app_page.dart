import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../repositories/catalog_store.dart';

IconData iconFor(EntityKind kind) => switch (kind) {
  EntityKind.books => Icons.menu_book,
  EntityKind.authors => Icons.edit_note,
  EntityKind.genres => Icons.category_outlined,
  EntityKind.publishers => Icons.business,
  EntityKind.readers => Icons.badge_outlined,
};

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
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: backPath == null ? 'Главная' : 'Назад',
          icon: Icon(
            backPath == null ? Icons.local_library_outlined : Icons.arrow_back,
          ),
          onPressed: () => context.go(backPath ?? '/'),
        ),
        actions: actions,
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in EntityKind.values)
                        ActionChip(
                          avatar: Icon(iconFor(kind), size: 18),
                          label: Text(kind.title),
                          onPressed: () => context.go(kind.path),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (store.notice != null) ...[
                    MaterialBanner(
                      content: Text(store.notice!),
                      actions: [
                        TextButton(
                          onPressed: store.dismissNotice,
                          child: const Text('Понятно'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
