import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../services/tv_service.dart';

/// Wraps a child widget with a visible focus ring when running on Android TV.
///
/// On non-TV platforms this is a pass-through with no visual overhead.
/// On TV, when the wrapped [FocusNode] gains focus, a rounded border
/// in the accent color is drawn around the child. D-pad select/enter
/// triggers [onSelect].
class TvFocusHighlight extends StatefulWidget {
  const TvFocusHighlight({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onSelect,
    this.borderRadius = 8.0,
  });

  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onSelect;
  final double borderRadius;

  @override
  State<TvFocusHighlight> createState() => _TvFocusHighlightState();
}

class _TvFocusHighlightState extends State<TvFocusHighlight> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  Worker? _tvWorker;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    // Listen for async TV detection result
    if (Get.isRegistered<TvService>()) {
      final tvService = Get.find<TvService>();
      // If already detected, we're fine — build will pick it up via Obx below.
      // If not, listen for the change so we rebuild when detection completes.
      _tvWorker = ever(tvService.isTV, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  bool _isTv() {
    if (!Get.isRegistered<TvService>()) return false;
    return Get.find<TvService>().isTV.value;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _tvWorker?.dispose();
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTv()) return widget.child;

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: _onKey,
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
