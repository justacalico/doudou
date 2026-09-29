import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Hairline row of the servers Doudou talks to.
class BackendStrip extends StatelessWidget {
  const BackendStrip({super.key});

  static const _backends = [
    'Subsonic',
    'OpenSubsonic',
    'Jellyfin',
    'Plex',
    'YouTube Music',
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final nameStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 15,
      color: Tk.ink2,
    );

    final names = _backends
        .map(
          (b) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tk.spaceXs,
              vertical: Tk.spaceXs,
            ),
            child: Text(b, style: nameStyle, maxLines: 1, softWrap: false),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Tk.paper,
        border: Border(
          top: BorderSide(color: Tk.rule2),
          bottom: BorderSide(color: Tk.rule2),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Tk.pagePadding(width),
        vertical: Tk.spaceSm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: width > Tk.wide
              ? Row(
                  children: [
                    Text(
                      'Streams from',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Spacer(),
                    for (var i = 0; i < names.length; i++) ...[
                      if (i > 0)
                        Container(width: 1, height: 16, color: Tk.rule),
                      names[i],
                    ],
                  ],
                )
              : Wrap(
                  spacing: Tk.spaceSm,
                  runSpacing: Tk.space2xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Streams from',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    ...names,
                  ],
                ),
        ),
      ),
    );
  }
}
