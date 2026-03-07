import 'package:flutter/material.dart';

class LibraryBookmarkIcon extends StatelessWidget {
  const LibraryBookmarkIcon({
    super.key,
    required this.isBookmarked,
    this.size,
    this.unbookmarkedColor,
  });

  final bool isBookmarked;
  final double? size;
  final Color? unbookmarkedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
      size: size,
      color: isBookmarked
          ? theme.colorScheme.primary
          : (unbookmarkedColor ??
              theme.iconTheme.color ??
              theme.colorScheme.onSurfaceVariant),
    );
  }
}
