import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int wideColumns;
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.wideColumns = 3,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final columns = screenWidth < 600
          ? 1
          : screenWidth < 1100
          ? 2
          : wideColumns;
      const gap = 16.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
