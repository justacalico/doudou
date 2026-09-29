import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A real app screenshot in a hairline-bordered figure. No drawn device
/// chrome: the border and one soft shadow do the work.
class Shot extends StatelessWidget {
  const Shot({super.key, required this.asset, required this.alt, this.radius});

  final String asset;
  final String alt;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? 24);
    return Semantics(
      image: true,
      label: alt,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: Tk.rule),
          boxShadow: [
            BoxShadow(
              color: Tk.ink.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
