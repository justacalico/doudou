import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../search_result_screen_controller.dart';

/// Read-only pill styled like the search bar showing the active query on the
/// result screen. Tapping it reopens the search page with the query restored
/// in the search field for editing.
class SearchQueryBar extends StatelessWidget {
  const SearchQueryBar({super.key, required this.controller});

  final SearchResultScreenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark
          ? Colors.black.withValues(alpha: 0.35)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: controller.editQuery,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(
                  () => Text(
                    controller.queryString.value,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
