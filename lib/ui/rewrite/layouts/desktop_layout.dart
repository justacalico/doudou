import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/adaptive_shell_content.dart';
import '../shell/adaptive_shell_state.dart';

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key, required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdaptiveShellState>(
      builder: (context, shellState, _) {
        final body = PageStorage(
          bucket: shellState.pageStorageBucket,
          child: AdaptiveShellContent(
            section: shellState.selectedSection,
            isCupertino: isCupertino,
          ),
        );

        return Scaffold(
          body: SafeArea(
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
                      _DesktopTopBar(
                        title: labelForSection(
                          context,
                          shellState.selectedSection,
                        ),
                      ),
                      Expanded(child: body),
                      NowPlayingBar(isCupertino: isCupertino),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
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
          const Text(
            'Doudou',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...AppShellSection.values.map((section) {
            final selected = section == selectedSection;
            return CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: selected
                  ? CupertinoColors.activeBlue.withValues(alpha: 0.14)
                  : CupertinoColors.systemGrey6.resolveFrom(context),
              onPressed: () => onSelected(section),
              child: Row(
                children: [
                  Icon(cupertinoIconForSection(section), size: 18),
                  const SizedBox(width: 8),
                  Text(labelForSection(context, section)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
