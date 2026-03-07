import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/constants/doudou_design.dart';
import '/ui/constants/layout.dart';
import '/ui/shell_controller.dart';
import '/utils/app_l10n.dart';
import 'library_controller.dart';
import 'library.dart';

class LibraryBrowseScreen extends StatefulWidget {
  const LibraryBrowseScreen({
    super.key,
    this.onSwitchToTab,
  });

  final void Function(int libraryTabIndex)? onSwitchToTab;

  @override
  State<LibraryBrowseScreen> createState() => _LibraryBrowseScreenState();
}

class _LibraryBrowseScreenState extends State<LibraryBrowseScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;
    final leftPadding = useBottomNav
        ? kContentLeftPaddingLibraryWithBottomNav
        : kContentLeftPaddingWithoutBottomNav;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: kContentRightPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                context.l10n.library,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: kDoudouPurple,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.libraryOverviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: kDoudouZinc500,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() {
            final albumsCount = Get.isRegistered<LibraryAlbumsController>()
                ? Get.find<LibraryAlbumsController>().libraryAlbums.length
                : 0;
            final songsCount = Get.isRegistered<LibrarySongsController>()
                ? Get.find<LibrarySongsController>().librarySongsList.length
                : 0;
            final artistsCount = Get.isRegistered<LibraryArtistsController>()
                ? Get.find<LibraryArtistsController>().libraryArtists.length
                : 0;
            final playlistsCount =
                Get.isRegistered<LibraryPlaylistsController>()
                    ? Get.find<LibraryPlaylistsController>().libraryPlaylists.length
                    : 0;

            final tabs = <_TabItem>[];
            if (albumsCount > 0) tabs.add(_TabItem(context.l10n.albums, 0));
            if (songsCount > 0) tabs.add(_TabItem(context.l10n.songs, 1));
            if (artistsCount > 0) tabs.add(_TabItem(context.l10n.artists, 2));
            if (playlistsCount > 0) tabs.add(_TabItem(context.l10n.playlists, 3));
            tabs.add(_TabItem(context.l10n.downloads, 4));

            if (tabs.isEmpty) {
              return Expanded(
                child: Center(
                  child: Text(
                    context.l10n.homeEmptyLibraryMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final selected = _selectedTabIndex.clamp(0, tabs.length - 1);
            if (selected != _selectedTabIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedTabIndex = selected);
              });
            }
            final contentIndex = tabs[selected].contentIndex;

            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LibraryTopbar(
                    tabs: tabs,
                    selectedIndex: selected,
                    onTap: (i) => setState(() => _selectedTabIndex = i),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: IndexedStack(
                      index: contentIndex,
                      children: const [
                        PlaylistNAlbumLibraryWidget(
                          isAlbumContent: true,
                          isBottomNavActive: true,
                        ),
                        SongsLibraryWidget(isBottomNavActive: true),
                        LibraryArtistWidget(isBottomNavActive: true),
                        PlaylistNAlbumLibraryWidget(
                          isAlbumContent: false,
                          isBottomNavActive: true,
                        ),
                        DownloadsLibraryWidget(isBottomNavActive: true),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.label, this.contentIndex);
  final String label;
  final int contentIndex;
}

class _LibraryTopbar extends StatelessWidget {
  const _LibraryTopbar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_TabItem> tabs;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = i == selectedIndex;
              return Padding(
                padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        tabs[i].label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? onSurface : muted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: kDoudouBorderStrong,
        ),
      ],
    );
  }
}
