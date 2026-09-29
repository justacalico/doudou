import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'controls.dart';

/// Edge-aligned minimal bar: wordmark hard-left, one CTA hard-right,
/// nothing between. A mostly-opaque tint mimics the frosted look without
/// paying for a BackdropFilter on every scroll frame.
class SiteNav extends StatelessWidget {
  const SiteNav({super.key, required this.scrolled, required this.onDownload});

  final bool scrolled;
  final VoidCallback onDownload;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedContainer(
      duration: Tk.durShort,
      curve: Tk.easeOut,
      height: height,
      decoration: BoxDecoration(
        color: Tk.paper.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: scrolled ? Tk.rule : const Color(0x00000000),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: Tk.pagePadding(width)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/icon.png',
              width: 30,
              height: 30,
              semanticLabel: 'Doudou icon',
            ),
          ),
          const SizedBox(width: Tk.spaceSm),
          Flexible(
            child: Text(
              'Doudou',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          PillButton(label: 'Download', compact: true, onPressed: onDownload),
        ],
      ),
    );
  }
}
