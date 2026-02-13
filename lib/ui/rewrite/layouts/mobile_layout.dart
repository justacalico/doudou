import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/app_state.dart';
import '../shell/adaptive_shell_content.dart';
import '../shell/adaptive_shell_state.dart';

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key, required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdaptiveShellState>(
      builder: (context, shellState, _) {
        final title = labelForSection(context, shellState.selectedSection);

        final body = PageStorage(
          bucket: shellState.pageStorageBucket,
          child: AdaptiveShellContent(
            section: shellState.selectedSection,
            isCupertino: isCupertino,
          ),
        );

        if (isCupertino) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(title),
              trailing: const SizedBox(
                width: 74,
                child: _ShuffleBarActions(isCupertino: true),
              ),
            ),
            child: Column(
              children: [
                Expanded(child: body),
                const NowPlayingBar(isCupertino: true),
                _CupertinoNavBar(
                  selectedSection: shellState.selectedSection,
                  onSelected: shellState.selectSection,
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: const [_ShuffleBarActions(isCupertino: false)],
          ),
          body: Column(
            children: [
              Expanded(child: body),
              const NowPlayingBar(isCupertino: false),
            ],
          ),
          bottomNavigationBar: _MaterialNavBar(
            selectedSection: shellState.selectedSection,
            onSelected: shellState.selectSection,
          ),
        );
      },
    );
  }
}

class _MaterialNavBar extends StatelessWidget {
  const _MaterialNavBar({
    required this.selectedSection,
    required this.onSelected,
  });

  final AppShellSection selectedSection;
  final ValueChanged<AppShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final sections = AppShellSection.values;
    final currentIndex = sections.indexOf(selectedSection);
    final compact = MediaQuery.sizeOf(context).width < 560;

    return NavigationBar(
      selectedIndex: currentIndex,
      labelBehavior: compact
          ? NavigationDestinationLabelBehavior.onlyShowSelected
          : NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) => onSelected(sections[index]),
      destinations: sections
          .map(
            (section) => NavigationDestination(
              icon: Icon(materialIconForSection(section)),
              label: labelForSection(context, section),
            ),
          )
          .toList(),
    );
  }
}

class _CupertinoNavBar extends StatelessWidget {
  const _CupertinoNavBar({
    required this.selectedSection,
    required this.onSelected,
  });

  final AppShellSection selectedSection;
  final ValueChanged<AppShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final sections = AppShellSection.values;
    final currentIndex = sections.indexOf(selectedSection);
    final compact = MediaQuery.sizeOf(context).width < 560;

    return CupertinoTabBar(
      currentIndex: currentIndex,
      onTap: (index) => onSelected(sections[index]),
      items: sections
          .map(
            (section) => BottomNavigationBarItem(
              icon: Icon(cupertinoIconForSection(section)),
              label: compact ? '' : labelForSection(context, section),
            ),
          )
          .toList(),
    );
  }
}

class _ShuffleBarActions extends StatelessWidget {
  const _ShuffleBarActions({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (isCupertino) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                minSize: 0,
                padding: EdgeInsets.zero,
                onPressed: appState.shuffleAllTracks,
                child: const Icon(CupertinoIcons.shuffle, size: 20),
              ),
              CupertinoButton(
                minSize: 0,
                padding: EdgeInsets.zero,
                onPressed: appState.shuffleFavoriteTracks,
                child: const Icon(CupertinoIcons.heart, size: 20),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.l10n.shuffleAll,
              onPressed: appState.shuffleAllTracks,
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              tooltip: context.l10n.shuffleFavorites,
              onPressed: appState.shuffleFavoriteTracks,
              icon: const Icon(Icons.favorite_rounded),
            ),
          ],
        );
      },
    );
  }
}
