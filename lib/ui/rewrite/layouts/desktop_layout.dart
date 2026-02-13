import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/app_state.dart';
import '../shell/adaptive_shell_content.dart';
import '../shell/adaptive_shell_state.dart';

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key, required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdaptiveShellState>(
      builder: (context, shellState, _) {
        final body = SafeArea(
          child: Row(
            children: [
              isCupertino
                  ? _CupertinoSidebar(
                      selectedSection: shellState.selectedSection,
                      onSelected: shellState.selectSection,
                    )
                  : _MaterialSidebar(
                      selectedSection: shellState.selectedSection,
                      onSelected: shellState.selectSection,
                    ),
              Expanded(
                child: Column(
                  children: [
                    _DesktopTopBar(isCupertino: isCupertino),
                    Expanded(
                      child: PageStorage(
                        bucket: shellState.pageStorageBucket,
                        child: AdaptiveShellContent(
                          section: shellState.selectedSection,
                          isCupertino: isCupertino,
                        ),
                      ),
                    ),
                    NowPlayingBar(isCupertino: isCupertino),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isCupertino) {
          return CupertinoPageScaffold(child: body);
        }

        return Scaffold(body: body);
      },
    );
  }
}

class _MaterialSidebar extends StatelessWidget {
  const _MaterialSidebar({
    required this.selectedSection,
    required this.onSelected,
  });

  final AppShellSection selectedSection;
  final ValueChanged<AppShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final sections = AppShellSection.values;
    final selectedIndex = sections.indexOf(selectedSection);

    return NavigationRail(
      selectedIndex: selectedIndex,
      extended: MediaQuery.sizeOf(context).width >= 1220,
      destinations: sections
          .map(
            (section) => NavigationRailDestination(
              icon: Icon(materialIconForSection(section)),
              label: Text(labelForSection(context, section)),
            ),
          )
          .toList(),
      onDestinationSelected: (index) => onSelected(sections[index]),
    );
  }
}

class _CupertinoSidebar extends StatelessWidget {
  const _CupertinoSidebar({
    required this.selectedSection,
    required this.onSelected,
  });

  final AppShellSection selectedSection;
  final ValueChanged<AppShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 8),
          Text(
            context.l10n.appName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...AppShellSection.values.map((section) {
            final selected = section == selectedSection;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: selected
                    ? CupertinoColors.activeBlue.withValues(alpha: 0.14)
                    : CupertinoColors.systemGrey6.resolveFrom(context),
                onPressed: () => onSelected(section),
                child: Row(
                  children: [
                    Icon(cupertinoIconForSection(section), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labelForSection(context, section),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCupertino
        ? CupertinoColors.separator.resolveFrom(context)
        : Theme.of(context).dividerColor;

    final background = isCupertino
        ? CupertinoColors.systemBackground.resolveFrom(context)
        : Theme.of(context).colorScheme.surface;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.appName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Consumer<AppState>(
            builder: (context, appState, _) {
              if (isCupertino) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: appState.shuffleAllTracks,
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.shuffle, size: 18),
                            const SizedBox(width: 6),
                            Text(context.l10n.shuffleAll),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: appState.shuffleFavoriteTracks,
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.heart, size: 18),
                            const SizedBox(width: 6),
                            Text(context.l10n.shuffleFavorites),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: appState.shuffleAllTracks,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: Text(context.l10n.shuffleAll),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: appState.shuffleFavoriteTracks,
                      icon: const Icon(Icons.favorite_rounded),
                      label: Text(context.l10n.shuffleFavorites),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
