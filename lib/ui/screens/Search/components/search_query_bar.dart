import 'package:flutter/material.dart';

import '/ui/widgets/modified_text_field.dart';
import '../search_result_screen_controller.dart';
import 'search_clear_button.dart';

/// Search-bar-styled pill on the result screen holding the active query.
/// Tapping into it lets the query be edited and resubmitted in place without
/// leaving the result page.
class SearchQueryBar extends StatelessWidget {
  const SearchQueryBar({super.key, required this.controller});

  final SearchResultScreenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.dividerColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ModifiedTextField(
              controller: controller.queryEditingController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSubmitted,
              style: theme.textTheme.titleMedium,
              cursorColor: theme.textTheme.bodySmall!.color,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SearchClearButton(
            controller: controller.queryEditingController,
            onPressed: controller.clearQueryEditText,
          ),
        ],
      ),
    );
  }

  void _onSubmitted(String value) {
    FocusManager.instance.primaryFocus?.unfocus();
    controller.submitSearch(value);
  }
}
