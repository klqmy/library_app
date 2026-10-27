import 'package:flutter/material.dart';

class EntityCardList<T> extends StatelessWidget {
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final Widget Function(T item) itemBuilder;
  final List<Widget> Function(T item)? actions;

  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.selected = const {},
    this.onToggleSelect,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = idOf(item);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: onToggleSelect != null
                ? Checkbox(
                    value: selected.contains(id),
                    onChanged: (_) => onToggleSelect!(id),
                  )
                : null,
            title: itemBuilder(item),
            trailing: actions != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!(item),
                  )
                : null,
          ),
        );
      },
    );
  }
}