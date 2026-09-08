import 'package:flutter/material.dart';

class SearchClearButton extends StatelessWidget {
  const SearchClearButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  final TextEditingController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          onPressed: onPressed,
          icon: Icon(
            Icons.close,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          splashRadius: 16,
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }
}
