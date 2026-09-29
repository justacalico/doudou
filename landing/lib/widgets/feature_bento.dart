import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'reveal.dart';
import 'section_shell.dart';

class _Tile {
  const _Tile(this.icon, this.title, this.body, this.flex);

  final IconData icon;
  final String title;
  final String body;
  final int flex;
}

/// Irregular bento of the feature set. Span mix is the rhythm; icons sit
/// inline with the title instead of above it.
class FeatureBento extends StatelessWidget {
  const FeatureBento({super.key});

  static const _rows = [
    [
      _Tile(
        Icons.download_for_offline_outlined,
        'Offline downloads',
        'Long-press any song, album, or playlist. It stays in the app, '
            'ready when the network is not.',
        2,
      ),
      _Tile(
        Icons.lyrics_outlined,
        'Synced lyrics',
        'Time-stamped words when the server provides them.',
        1,
      ),
      _Tile(
        Icons.radio_outlined,
        'Radio mode',
        'Seed one song; the mix keeps going after the album ends.',
        1,
      ),
    ],
    [
      _Tile(
        Icons.devices_other_outlined,
        'Watch and TV',
        'Wear OS on the wrist, a D-pad UI on the sofa.',
        1,
      ),
      _Tile(
        Icons.forum_outlined,
        'Discord presence',
        'Shows what is playing while you listen at the desk.',
        1,
      ),
      _Tile(
        Icons.graphic_eq,
        'Gapless playback',
        'Albums play through the way they were mastered, with a real '
            'queue and history behind it.',
        2,
      ),
    ],
    [
      _Tile(
        Icons.directions_car_outlined,
        'In the car',
        'Android Auto and CarPlay put the queue on the dashboard.',
        2,
      ),
      _Tile(
        Icons.tune,
        'Transcoding',
        'Uses server-side transcoding when bandwidth is tight.',
        1,
      ),
      _Tile(
        Icons.palette_outlined,
        'Dynamic themes',
        'The interface takes its colours from the album art.',
        1,
      ),
    ],
  ];

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
          Reveal(child: Text('Everything a player should do.', style: heading)),
          const SizedBox(height: Tk.space3xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w > Tk.wide) {
                return Column(
                  children: [
                    for (final row in _rows) ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < row.length; i++) ...[
                              if (i > 0) const SizedBox(width: Tk.spaceMd),
                              Expanded(
                                flex: row[i].flex,
                                child: Reveal(child: _BentoTile(row[i])),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Tk.spaceMd),
                    ],
                  ],
                );
              }
              final flat = _rows.expand((r) => r).toList();
              if (w > 560) {
                return Column(
                  children: [
                    for (var i = 0; i < flat.length; i += 2) ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: Reveal(child: _BentoTile(flat[i]))),
                            const SizedBox(width: Tk.spaceMd),
                            Expanded(
                              child: i + 1 < flat.length
                                  ? Reveal(child: _BentoTile(flat[i + 1]))
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Tk.spaceMd),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (final t in flat) ...[
                    Reveal(child: _BentoTile(t)),
                    const SizedBox(height: Tk.spaceMd),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile(this.tile);

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tk.spaceLg),
      decoration: BoxDecoration(
        color: Tk.paper2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tile.icon, size: 20, color: Tk.accent),
              const SizedBox(width: Tk.spaceXs),
              Expanded(
                child: Text(
                  tile.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tk.spaceSm),
          Text(
            tile.body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
