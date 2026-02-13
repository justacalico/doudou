import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            navigationBar: CupertinoNavigationBar(middle: Text(title)),
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
            actions: [
              Consumer<AppState>(
                builder: (context, appState, _) {
                  return IconButton(
                    onPressed: appState.isLoading
                        ? null
                        : appState.refreshLibraryData,
                    icon: const Icon(Icons.refresh_rounded),
                  );
                },
              ),
            ],
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

    return NavigationBar(
      selectedIndex: currentIndex,
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

    return CupertinoTabBar(
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
    );
  }
}
