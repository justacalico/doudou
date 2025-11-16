import 'package:flutter/material.dart';

/// TV Focus Border Widget
/// 
/// Provides a visual border when a widget receives focus from remote/D-pad navigation
class TVFocusBorder extends StatefulWidget {
  final Widget child;
  final Color focusColor;
  final double borderWidth;
  final double borderRadius;

  const TVFocusBorder({
    super.key,
    required this.child,
    this.focusColor = Colors.purple,
    this.borderWidth = 3.0,
    this.borderRadius = 12.0,
  });

  @override
  State<TVFocusBorder> createState() => _TVFocusBorderState();
}

class _TVFocusBorderState extends State<TVFocusBorder> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isFocused ? widget.focusColor : Colors.transparent,
            width: widget.borderWidth,
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: widget.focusColor.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
