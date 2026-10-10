import 'package:flutter/material.dart';

import '../links.dart';
import '../theme/tokens.dart';
import 'controls.dart';
import 'reveal.dart';
import 'section_shell.dart';
import 'shot.dart';
import 'site_nav.dart';

/// Split-diptych hero: statement and CTAs on the left, a pair of real
/// phone screenshots on the right. Stacks on narrow screens.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final display = Theme.of(context).textTheme.displayLarge!.copyWith(
      fontSize: Tk.displaySize(width),
    );

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: Text(
            'Every song you have.\nOn every screen you own.',
            style: display,
          ),
        ),
        const SizedBox(height: Tk.spaceLg),
        Reveal(
          delay: const Duration(milliseconds: 90),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              'Doudou streams your Subsonic, Jellyfin, Plex, or '
              'YouTube Music library to your phone, TV, and desktop. '
              'Free and open source.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: Tk.spaceXl),
        Reveal(
          delay: const Duration(milliseconds: 180),
          child: Wrap(
            spacing: Tk.spaceMd,
            runSpacing: Tk.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillButton(label: 'Download', onPressed: onDownload),
              TextLink(
                label: 'Source on GitLab',
                onPressed: () => Links.open(Links.repo),
              ),
            ],
          ),
        ),
      ],
    );

    const shots = _PhonePair(
      front: 'assets/screens/home.png',
      behind: 'assets/screens/nowplaying.png',
    );

    return SectionShell(
      paddingTop: SiteNav.height + Tk.space3xl,
      paddingBottom: Tk.space4xl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > Tk.wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 11, child: copy),
                const SizedBox(width: Tk.space3xl),
                const Expanded(flex: 9, child: shots),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: Tk.space3xl),
              const _PhonePair(
                front: 'assets/screens/home.png',
                behind: 'assets/screens/nowplaying.png',
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Two phone screenshots, the second set lower and slightly recessed.
class _PhonePair extends StatelessWidget {
  const _PhonePair({required this.front, required this.behind});

  final String front;
  final String behind;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      delay: const Duration(milliseconds: 240),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Shot(asset: front, alt: 'Doudou home screen on Android'),
          ),
          const SizedBox(width: Tk.spaceMd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Tk.space3xl),
              child: Shot(
                asset: behind,
                alt: 'Doudou now playing screen on Android',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
