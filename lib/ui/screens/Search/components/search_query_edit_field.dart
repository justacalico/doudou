import 'package:flutter/material.dart';

import '../search_result_screen_controller.dart';
import 'search_text_field.dart';

/// Editable query line shown on the search result screen so the search can be
/// tweaked and resubmitted without navigating back to the search page.
class SearchQueryEditField extends StatelessWidget {
  const SearchQueryEditField({
    super.key,
    required this.controller,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final SearchResultScreenController controller;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return SearchTextField(
      controller: controller.queryEditingController,
      onChanged: null,
      onSubmitted: _onSubmitted,
      onClear: controller.clearQueryEditText,
      style: style,
      textAlign: textAlign,
    );
  }

  void _onSubmitted(String value) {
    FocusManager.instance.primaryFocus?.unfocus();
    controller.submitSearch(value);
  }
}
