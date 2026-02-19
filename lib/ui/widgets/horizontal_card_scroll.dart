import 'package:flutter/material.dart';

import '../theme.dart';

/// Horizontally scrolling row of cards. Takes list and card builder.
class HorizontalCardScroll extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double height;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const HorizontalCardScroll({
    super.key,
    required this.itemCount,
    required this.itemWidth,
    required this.height,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < itemCount - 1 ? AppTheme.spacingMd : 0,
            ),
            child: itemBuilder(context, index),
          );
        },
      ),
    );
  }
}
