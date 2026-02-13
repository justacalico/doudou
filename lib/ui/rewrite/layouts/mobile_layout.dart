import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/adaptive_shell_content.dart';
import '../shell/adaptive_shell_state.dart';

const List<AppShellSection> _mobileNavSections = <AppShellSection>[
  AppShellSection.home,
  AppShellSection.tracks,
  AppShellSection.downloads,
  AppShellSection.favorites,
  AppShellSection.settings,
];

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key, required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdaptiveShellState>(
      builder: (context, shellState, _) {
        final activeSection =
            _mobileNavSections.contains(shellState.selectedSection)
            ? shellState.selectedSection
            : AppShellSection.home;
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
            navigationBar: CupertinoNavigationBar(middle: Text(title)),
            child: Column(
              children: [
                Expanded(child: body),
                const NowPlayingBar(isCupertino: true),
                _CupertinoNavBar(
                  selectedSection: activeSection,
                  onSelected: shellState.selectSection,
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Column(
            children: [
              Expanded(child: body),
              const NowPlayingBar(isCupertino: false),
            ],
          ),
          bottomNavigationBar: _MaterialNavBar(
            selectedSection: activeSection,
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
    final sections = _mobileNavSections;
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
    final sections = _mobileNavSections;
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
