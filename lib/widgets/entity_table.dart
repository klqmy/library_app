import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          ...columns.map((col) {
            Widget label = Text(col.label);
            if (col.sortField != null && col.sortField == sortField) {
              label = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(col.label),
                  const SizedBox(width: 4),
                  Icon(
                    sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                ],
              );
            }
            return DataColumn(
              label: label,
              numeric: col.numeric,
              onSort: col.sortField != null && onSort != null
                  ? (ascending, _) => onSort!(col.sortField!)
                  : null,
            );
          }),
          if (actions != null) const DataColumn(label: Text('Действия')),
        ],
        rows: items.map((item) {
          final id = idOf(item);
          return DataRow(
            selected: selected.contains(id),
            onSelectChanged: onToggleSelect != null
                ? (_) => onToggleSelect!(id)
                : null,
            cells: [
              ...columns.map((col) => DataCell(col.build(item))),
              if (actions != null)
                DataCell(
                  Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
