import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/tv_service.dart';

/// Wraps a child widget with a visible focus ring when running on Android TV.
///
/// On non-TV platforms this is a pass-through with no visual overhead.
/// On TV, when the wrapped [FocusNode] gains focus, a rounded border
/// in the accent color is drawn around the child.
class TvFocusHighlight extends StatefulWidget {
  const TvFocusHighlight({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.borderRadius = 8.0,
  });

  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final double borderRadius;

  @override
  State<TvFocusHighlight> createState() => _TvFocusHighlightState();
}

class _TvFocusHighlightState extends State<TvFocusHighlight> {
  late FocusNode _focusNode;
  bool _isTv = false;

  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _checkTv();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _checkTv() {
    if (Get.isRegistered<TvService>()) {
      _isTv = Get.find<TvService>().isTV.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    // Only dispose if we created it internally
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTv) return widget.child;

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: widget.onFocusChange,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: _hasFocus
              ? Border.all(color: accentColor, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: widget.child,
      ),
    );
  }
}
