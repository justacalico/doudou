import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';

/// Pill button. `primary` fills with the accent; otherwise it stays outlined.
/// Labels never wrap: a button reads as one line at every width.
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool compact;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: widget.primary ? Tk.accentInk : Tk.ink,
      fontSize: widget.compact ? 14 : 16,
    );
    final dy = _pressed ? 0.5 : (_hover ? -1.5 : 0.0);

    return FocusableActionDetector(
      enabled: _enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTap: widget.onPressed,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            button: true,
            enabled: _enabled,
            label: widget.label,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _focused ? Tk.accent : const Color(0x00000000),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(Tk.space3xs),
              child: AnimatedContainer(
                duration: Tk.durShort,
                curve: Tk.easeOut,
                transform: Matrix4.translationValues(0, dy, 0),
                transformAlignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: Tk.spaceLg,
                  vertical: Tk.spaceSm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: !_enabled
                      ? Tk.rule2
                      : widget.primary
                      ? (_hover ? Tk.accentDeep : Tk.accent)
                      : Tk.paper,
                  border: widget.primary
                      ? null
                      : Border.all(color: _hover ? Tk.muted : Tk.rule),
                ),
                child: Text(
                  widget.label,
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline text link. Underlines on hover, arrow nudges right.
class TextLink extends StatefulWidget {
  const TextLink({
    super.key,
    required this.label,
    this.onPressed,
    this.arrow = true,
    this.size = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool arrow;
  final double size;

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover || _focused ? Tk.accent : Tk.ink;
    final style = GoogleFonts.geist(
      fontSize: widget.size,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: color,
      decoration: _hover ? TextDecoration.underline : TextDecoration.none,
      decorationColor: color,
      decorationThickness: 1.5,
    );

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: SystemMouseCursors.click,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            link: true,
            label: widget.label,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Tk.spaceXs,
                horizontal: Tk.space2xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _focused ? Tk.accent : const Color(0x00000000),
                  width: 1.5,
                ),
              ),
              child: AnimatedDefaultTextStyle(
                duration: Tk.durShort,
                curve: Tk.easeOut,
                style: style,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.arrow) ...[
                      const SizedBox(width: Tk.space2xs),
                      const Text('›'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
