import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// One-shot reveal: fades and rises 10 px when it first enters the viewport.
/// Never re-fires. With reduced motion on, the child renders immediately.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Tk.durLong,
  );
  ScrollPosition? _position;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _played) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _played = true;
      _controller.value = 1;
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewport = MediaQuery.sizeOf(context).height;
    if (top <= viewport * 0.92) {
      _play();
      return;
    }
    _position ??= Scrollable.maybeOf(context)?.position;
    if (_position == null || !_position!.hasPixels) {
      _play();
    } else {
      _position!.addListener(_check);
    }
  }

  void _play() {
    _played = true;
    _position?.removeListener(_check);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Tk.easeOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: widget.child,
    );
  }
}
