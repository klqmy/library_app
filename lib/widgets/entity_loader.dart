import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entity_kind.dart';
import '../repositories/catalog_store.dart';
import 'app_page.dart';
import 'request_state.dart';

class EntityLoader extends StatefulWidget {
  final EntityKind kind;
  final int? id;
  final bool detail;
  final WidgetBuilder builder;
  const EntityLoader({
    super.key,
    required this.kind,
    this.id,
    this.detail = false,
    required this.builder,
  });
  @override
  State<EntityLoader> createState() => _EntityLoaderState();
}

class _EntityLoaderState extends State<EntityLoader> {
  late Future<void> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<CatalogStore>().prepare(
      widget.kind,
      id: widget.id,
      detail: widget.detail,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.builder(context);
      }
      return AppPage(
        title: widget.kind.singular,
        backPath: widget.kind.path,
        child: RequestState(
          error: snapshot.error,
          retry: () => setState(_load),
        ),
      );
    },
  );
}
