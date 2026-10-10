import 'package:flutter/material.dart';

import '../links.dart';
import '../theme/tokens.dart';
import 'reveal.dart';
import 'section_shell.dart';

class _Row {
  const _Row(this.label, this.value, [this.link]);

  final String label;
  final String value;
  final String? link;
}

/// Tabular spec sheet: hairline rows of label and value, the way a
/// tech-specs page reads.
class SpecSheet extends StatelessWidget {
  const SpecSheet({super.key});

  static const _rows = [
    _Row(
      'Platforms',
      'Android, Android TV, iOS, macOS, Windows, Linux',
    ),
    _Row(
      'Backends',
      'Subsonic, OpenSubsonic, Jellyfin, Plex, YouTube Music',
    ),
    _Row('Offline', 'Songs, albums and playlists, kept inside the app'),
    _Row('License', 'GPL-3.0', Links.license),
    _Row('Price', 'Free'),
    _Row('Source', 'gitlab.com/Openlyst/doudou', Links.repo),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heading = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: Tk.headlineSize(width),
    );
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
      letterSpacing: 1.4,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: Tk.ink);

    return SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(child: Text('The fine print, up front.', style: heading)),
          const SizedBox(height: Tk.space3xl),
          for (final row in _rows)
            Reveal(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Tk.rule)),
                ),
                padding: const EdgeInsets.symmetric(vertical: Tk.spaceLg),
                child: width > Tk.wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          SizedBox(
                            width: 180,
                            child: Text(
                              row.label.toUpperCase(),
                              style: labelStyle,
                            ),
                          ),
                          Expanded(
                            child: _SpecValue(row: row, style: valueStyle),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.label.toUpperCase(), style: labelStyle),
                          const SizedBox(height: Tk.spaceXs),
                          _SpecValue(row: row, style: valueStyle),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecValue extends StatelessWidget {
  const _SpecValue({required this.row, required this.style});

  final _Row row;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (row.link == null) return Text(row.value, style: style);
    return GestureDetector(
      onTap: () => Links.open(row.link!),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          link: true,
          label: row.value,
          child: Text(
            row.value,
            style: style.copyWith(
              color: Tk.accent,
              decoration: TextDecoration.underline,
              decorationColor: Tk.accent,
            ),
          ),
        ),
      ),
    );
  }
}
