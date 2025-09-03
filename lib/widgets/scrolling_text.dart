import 'package:flutter/cupertino.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;
  final double maxWidth;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 6),
    this.pauseDuration = const Duration(seconds: 1),
    required this.maxWidth,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scrollAnimation;
  late Animation<double> _bounceAnimation;
  bool _needsScrolling = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.scrollDuration,
      vsync: this,
    );
    
    // Main scrolling animation with easing
    _scrollAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
    ));

    // Spring bounce animation at the end
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 1.0, curve: Curves.elasticOut),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollingNeeded();
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfScrollingNeeded();
      });
    }
  }

  void _checkIfScrollingNeeded() {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final textWidth = renderBox.size.width;
      setState(() {
        _needsScrolling = textWidth > widget.maxWidth;
      });
      
      if (_needsScrolling) {
        _startScrolling();
      }
    }
  }

  void _startScrolling() async {
    await Future.delayed(widget.pauseDuration);
    if (mounted && _needsScrolling) {
      await _controller.forward();
      await Future.delayed(const Duration(milliseconds: 300)); // Brief pause at end
      if (mounted) {
        // Quick spring back to start
        await _controller.animateBack(0.0, duration: const Duration(milliseconds: 400), curve: Curves.elasticOut);
        await Future.delayed(widget.pauseDuration);
        if (mounted) {
          _startScrolling();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.maxWidth,
      height: widget.style?.fontSize != null 
          ? (widget.style!.fontSize! * 1.2) 
          : 20,
      child: ClipRect(
        child: Stack(
          children: [
            // Invisible text to measure width
            Positioned(
              left: -10000,
              child: Text(
                widget.text,
                key: _textKey,
                style: widget.style,
              ),
            ),
            // Visible scrolling text
            if (_needsScrolling)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
                  final textWidth = renderBox?.size.width ?? 0;
                  final scrollDistance = textWidth - widget.maxWidth + 50; // Extra padding
                  
                  // Combine scroll and bounce animations
                  final scrollValue = _scrollAnimation.value;
                  final bounceValue = _bounceAnimation.value;
                  
                  // Apply spring effect at the end
                  final finalOffset = scrollDistance * scrollValue + 
                      (bounceValue > 0 ? scrollDistance * 0.1 * (1 - bounceValue) : 0);
                  
                  return Transform.translate(
                    offset: Offset(-finalOffset, 0),
                    child: Text(
                      widget.text,
                      style: widget.style,
                    ),
                  );
                },
              )
            else
              Text(
                widget.text,
                style: widget.style,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
