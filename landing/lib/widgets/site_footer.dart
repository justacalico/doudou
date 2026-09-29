import 'package:flutter/material.dart';

import '../links.dart';
import '../theme/tokens.dart';
import 'controls.dart';

/// Single inline line of credit and links above a hairline. No columns.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final muted = Theme.of(context).textTheme.labelSmall;

    Widget dot() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tk.space2xs),
      child: Text('·', style: muted),
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Tk.paper,
        border: Border(top: BorderSide(color: Tk.rule)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Tk.pagePadding(width),
        vertical: Tk.spaceXl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Doudou',
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              dot(),
              Text('GPL-3.0', style: muted),
              dot(),
              TextLink(
                label: 'Based on Harmony-Music',
                arrow: false,
                size: 13,
                onPressed: () => Links.open(Links.harmonyMusic),
              ),
              dot(),
              TextLink(
                label: 'GitLab',
                arrow: false,
                size: 13,
                onPressed: () => Links.open(Links.repo),
              ),
              dot(),
              TextLink(
                label: 'Releases',
                arrow: false,
                size: 13,
                onPressed: () => Links.open(Links.releases),
              ),
              dot(),
              TextLink(
                label: 'Issues',
                arrow: false,
                size: 13,
                onPressed: () => Links.open(Links.issues),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
