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
    this.debugLabel,
  });

  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onSelect;
  final double borderRadius;
  final String? debugLabel;

  @override
  State<TvFocusHighlight> createState() => _TvFocusHighlightState();
}

class _TvFocusHighlightState extends State<TvFocusHighlight> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  Worker? _tvWorker;
  bool _didAutofocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: widget.debugLabel);
    _focusNode.addListener(_onFocusChanged);

    // Check if TV is already detected (compile-time flag is synchronous)
    final currentlyTv = _isTv();
    if (currentlyTv && widget.autofocus && !_didAutofocus) {
      _didAutofocus = true;
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] TV already detected in initState, scheduling autofocus');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isTv()) {
          debugPrint('[TvFocusHighlight:${widget.debugLabel}] requesting autofocus (from initState)');
          _focusNode.requestFocus();
        }
      });
    }

    // Also listen for async TV detection (runtime detection path)
    if (Get.isRegistered<TvService>()) {
      final tvService = Get.find<TvService>();
      _tvWorker = ever(tvService.isTV, (_) {
        if (mounted) {
          debugPrint('[TvFocusHighlight:${widget.debugLabel}] TV state changed to ${tvService.isTV.value}, rebuilding');
          setState(() {});
          if (tvService.isTV.value && widget.autofocus && !_didAutofocus) {
            _didAutofocus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isTv()) {
                debugPrint('[TvFocusHighlight:${widget.debugLabel}] requesting autofocus (from worker)');
                _focusNode.requestFocus();
              }
            });
          }
        }
      });
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    debugPrint('[TvFocusHighlight:${widget.debugLabel}] focus changed: ${_focusNode.hasFocus}');
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  bool _isTv() {
    if (!Get.isRegistered<TvService>()) return false;
    return Get.find<TvService>().isTV.value;
  }

  void _escapeToParent(bool forward) {
    debugPrint('[TvFocusHighlight:${widget.debugLabel}] escaping to parent (forward=$forward)');
    // Walk up the focus tree to find a FocusScopeNode that can traverse
    // beyond the current FocusTraversalGroup
    var node = _focusNode.parent;
    while (node != null) {
      if (node is FocusScopeNode) {
        final result = forward ? node.nextFocus() : node.previousFocus();
        if (result) {
          debugPrint('[TvFocusHighlight:${widget.debugLabel}] escaped to parent scope successfully');
          return;
        }
      }
      node = node.parent;
    }
    debugPrint('[TvFocusHighlight:${widget.debugLabel}] no parent scope to escape to');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    debugPrint('[TvFocusHighlight:${widget.debugLabel}] key event: $key');
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] select/enter pressed, calling onSelect');
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }
    // D-pad arrows — traverse focus, escaping group boundaries when needed
    if (key == LogicalKeyboardKey.arrowDown) {
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] arrow down, traversing next');
      if (!_focusNode.nextFocus()) {
        _escapeToParent(true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] arrow up, traversing previous');
      if (!_focusNode.previousFocus()) {
        _escapeToParent(false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] arrow right, traversing next');
      if (!_focusNode.nextFocus()) {
        _escapeToParent(true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      debugPrint('[TvFocusHighlight:${widget.debugLabel}] arrow left, traversing previous');
      if (!_focusNode.previousFocus()) {
        _escapeToParent(false);
      }
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
    final isTv = _isTv();
    debugPrint('[TvFocusHighlight:${widget.debugLabel}] build, isTv=$isTv, hasFocus=$_hasFocus');

    if (!isTv) return widget.child;

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
