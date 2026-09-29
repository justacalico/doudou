import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'reveal.dart';
import 'section_shell.dart';

class _Qa {
  const _Qa(this.q, this.a);

  final String q;
  final String a;
}

/// Conversational FAQ. Hairline rows, one answer open at a time.
class FaqSection extends StatefulWidget {
  const FaqSection({super.key});

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  static const _items = [
    _Qa(
      'Can I listen away from home?',
      'Yes. As long as your server is reachable from the internet, Doudou '
          'works anywhere. A reverse proxy or VPN is a good idea.',
    ),
    _Qa(
      'Where do downloads go?',
      'Long-press a song, album, or playlist and choose download. Files '
          'stay inside the app, not in your public downloads folder.',
    ),
    _Qa(
      'Is the desktop app different?',
      'Same app, same backend. The layout adapts to the screen size and '
          'adds Discord presence and system media controls.',
    ),
    _Qa(
      'Is YouTube Music in every build?',
      'It is disabled in Play Store builds to comply with Google policy. '
          'Other builds include it.',
    ),
  ];

  int _open = -1;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heading = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: Tk.headlineSize(width),
    );

    return SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(child: Text('Questions, answered.', style: heading)),
          const SizedBox(height: Tk.space3xl),
          for (var i = 0; i < _items.length; i++)
            _FaqRow(
              qa: _items[i],
              open: _open == i,
              onTap: () => setState(() => _open = _open == i ? -1 : i),
            ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatefulWidget {
  const _FaqRow({required this.qa, required this.open, required this.onTap});

  final _Qa qa;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_FaqRow> createState() => _FaqRowState();
}

class _FaqRowState extends State<_FaqRow> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tk.rule)),
      ),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        mouseCursor: SystemMouseCursors.click,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              expanded: widget.open,
              label: widget.qa.q,
              child: AnimatedContainer(
                duration: Tk.durShort,
                curve: Tk.easeOut,
                color: _hover ? Tk.paper2 : const Color(0x00000000),
                padding: const EdgeInsets.symmetric(
                  vertical: Tk.spaceLg,
                  horizontal: Tk.spaceXs,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _focused
                                    ? Tk.accent
                                    : const Color(0x00000000),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(Tk.space2xs),
                            child: Text(
                              widget.qa.q,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: Tk.spaceMd),
                        AnimatedRotation(
                          turns: widget.open ? 0.25 : 0,
                          duration: Tk.durShort,
                          curve: Tk.easeOut,
                          child: const Icon(
                            Icons.chevron_right,
                            color: Tk.muted,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(
                          top: Tk.spaceSm,
                          right: Tk.space2xl,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.qa.a,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      crossFadeState: widget.open
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: Tk.durLong,
                      sizeCurve: Tk.easeInOut,
                    ),
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
