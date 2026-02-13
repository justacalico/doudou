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

    return NavigationBar(
      selectedIndex: currentIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    final surfaceColor = CupertinoColors.systemBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final theme = CupertinoTheme.of(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CupertinoTheme(
            data: theme.copyWith(barBackgroundColor: surfaceColor),
            child: CupertinoTabBar(
              backgroundColor: Colors.transparent,
              currentIndex: currentIndex,
              onTap: (index) => onSelected(sections[index]),
              items: sections
                  .map(
                    (section) => BottomNavigationBarItem(
                      icon: Icon(cupertinoIconForSection(section)),
                      label: labelForSection(context, section),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
