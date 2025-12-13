import 'package:flutter/material.dart';

/// A text widget that automatically scrolls horizontally when the text
/// overflows, similar to YouTube Music's song title display.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final Duration scrollDuration;
  final double blankSpace;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.scrollDuration = const Duration(seconds: 8),
    this.blankSpace = 50.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isOverflowing = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _isScrolling = false;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflow();
      });
    }
  }

  void _checkOverflow() {
    if (!mounted) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final shouldOverflow = maxScrollExtent > 0;

    if (shouldOverflow != _isOverflowing) {
      setState(() {
        _isOverflowing = shouldOverflow;
      });
    }

    if (_isOverflowing && !_isScrolling) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_isOverflowing) return;
    _isScrolling = true;

    while (mounted && _isOverflowing) {
      // Pause at the start
      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;

      // Scroll to end
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        await _scrollController.animateTo(
          maxScroll,
          duration: widget.scrollDuration,
          curve: Curves.linear,
        );
      }

      if (!mounted) return;

      // Pause at the end
      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;

      // Scroll back to start
      if (maxScroll > 0) {
        await _scrollController.animateTo(
          0,
          duration: widget.scrollDuration,
          curve: Curves.linear,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _isOverflowing
              ? [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ]
              : [Colors.white, Colors.white],
          stops: _isOverflowing ? [0.0, 0.05, 0.95, 1.0] : [0.0, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
