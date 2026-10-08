import 'package:flutter/material.dart';

import '/utils/app_l10n.dart';
import '/ui/widgets/modified_text_field.dart';
import 'search_clear_button.dart';

class SearchTextField extends StatelessWidget {
  const SearchTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModifiedTextField(
      textCapitalization: TextCapitalization.sentences,
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      cursorColor: theme.textTheme.bodySmall!.color,
      decoration: InputDecoration(
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
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintText: context.l10n.searchDes,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          fontSize: 14,
          height: 1.2,
        ),
        suffix: SearchClearButton(
          controller: controller,
          onPressed: onClear,
        ),
      ),
    );
  }
}
