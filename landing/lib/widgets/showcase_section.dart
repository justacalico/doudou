import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'reveal.dart';
import 'section_shell.dart';
import 'shot.dart';

/// One alternating diptych row: text on one side, a real screenshot on
/// the other. `flip` swaps which side the shot sits on.
class ShowcaseSection extends StatelessWidget {
  const ShowcaseSection({
    super.key,
    required this.title,
    required this.body,
    required this.asset,
    required this.alt,
    this.flip = false,
    this.banded = false,
    this.phone = false,
  });

  final String title;
  final String body;
  final String asset;
  final String alt;
  final bool flip;
  final bool banded;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heading = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: Tk.headlineSize(width),
    );

    final text = Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: heading),
          const SizedBox(height: Tk.spaceMd),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );

    final figure = Reveal(
      delay: const Duration(milliseconds: 120),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: phone ? 300 : 640),
          child: Shot(asset: asset, alt: alt, radius: phone ? 28 : 16),
        ),
      ),
    );

    return SectionShell(
      banded: banded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > Tk.wide;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: Tk.space3xl), figure],
            );
          }
          final first = flip ? figure : text;
          final second = flip ? text : figure;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: first),
              const SizedBox(width: Tk.space4xl),
              Expanded(child: second),
            ],
          );
        },
      ),
    );
  }
}
