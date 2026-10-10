import 'package:flutter/material.dart';

import '../links.dart';
import '../theme/tokens.dart';
import 'controls.dart';
import 'reveal.dart';
import 'section_shell.dart';

/// The download block: one accent CTA per platform, honest small print.
class DownloadSection extends StatelessWidget {
  const DownloadSection({super.key});

  static const platforms = [
    'Android',
    'Android TV',
    'iOS',
    'macOS',
    'Windows',
    'Linux',
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heading = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: Tk.headlineSize(width),
    );

    return SectionShell(
      banded: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Reveal(
                child: Text(
                  'Get Doudou.',
                  style: heading,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Tk.spaceMd),
              Reveal(
                delay: const Duration(milliseconds: 90),
                child: Text(
                  'Stable builds for every platform live on the download '
                  'page. Nightly builds live on GitLab Releases.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Tk.space2xl),
              Reveal(
                delay: const Duration(milliseconds: 160),
                child: Wrap(
                  spacing: Tk.spaceSm,
                  runSpacing: Tk.spaceSm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in platforms)
                      PillButton(
                        label: p,
                        primary: false,
                        compact: true,
                        onPressed: () => Links.open(Links.download),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Tk.spaceLg),
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: TextLink(
                  label: 'Nightly builds on GitLab',
                  onPressed: () => Links.open(Links.releases),
                ),
              ),
              const SizedBox(height: Tk.spaceXl),
              Reveal(
                delay: const Duration(milliseconds: 240),
                child: Text(
                  'Android APKs are signed with a debug key, so allow '
                  'installs from unknown sources. iOS and macOS builds are '
                  'unsigned and need local signing.',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
