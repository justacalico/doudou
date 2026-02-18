import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/ui/desktop/services/navigation_service.dart';

import 'package:doudou/ui/layout/breakpoint.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Library hub: quick links to Albums, Artists, Tracks, Playlists using shared templates.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) appState.loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isSoundCloud = appState.mediaServiceManager
                .currentServerType ==
            ServerType.soundcloud ||
        appState.mediaServiceManager.currentServerType ==
            ServerType.youtubeMusic;
        // Page indices match app_shell: when Albums is hidden (SoundCloud/YT), indices shift by 1.
        final albumsIndex = 3;
        final artistsIndex = isSoundCloud ? 3 : 4;
        final songsIndex = isSoundCloud ? 4 : 5;
        final playlistsIndex = isSoundCloud ? 5 : 6;
        return PageTemplate(
          title: l10n.navLibrary,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: l10n.libraryOverview,
                  subtitle: l10n.yourMusicCollection,
                ),
                const SizedBox(height: DesktopTheme.spacingMd),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow =
                        constraints.maxWidth < kLayoutBreakpoint;
                    final spacing = DesktopTheme.spacingMd;
                    final tileWidth = isNarrow
                        ? (constraints.maxWidth - spacing) / 2
                        : 160.0;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        if (!isSoundCloud)
                          _LibraryTile(
                            icon: Icons.album_rounded,
                            label: l10n.albums,
                            count: appState.albums.length,
                            onTap: () =>
                                NavigationService().selectPage(albumsIndex),
                            width: tileWidth,
                          ),
                        _LibraryTile(
                          icon: Icons.person_rounded,
                          label: l10n.artists,
                          count: appState.artists.length,
                          onTap: () =>
                              NavigationService().selectPage(artistsIndex),
                          width: tileWidth,
                        ),
                        _LibraryTile(
                          icon: Icons.music_note_rounded,
                          label: l10n.songs,
                          count: appState.tracks.length,
                          onTap: () =>
                              NavigationService().selectPage(songsIndex),
                          width: tileWidth,
                        ),
                        _LibraryTile(
                          icon: Icons.queue_music_rounded,
                          label: l10n.playlists,
                          count: appState.playlists.length,
                          onTap: () =>
                              NavigationService().selectPage(playlistsIndex),
                          width: tileWidth,
                        ),
                      ],
                    );
                  },
                ),
                if (!isSoundCloud && appState.albums.isNotEmpty) ...[
                  const SizedBox(height: DesktopTheme.spacingXl),
                  SectionHeader(
                    title: l10n.recentlyAddedAlbums,
                    onSeeAllPressed: () =>
                        NavigationService().selectPage(albumsIndex),
                  ),
                  const SizedBox(height: DesktopTheme.spacingMd),
                  SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: appState.albums.take(8).length,
                      itemBuilder: (context, index) {
                        final album = appState.albums[index];
                        final imageUrl = album.imageUrl != null
                            ? appState.getImageUrl(album.imageUrl!)
                            : null;
                        return Padding(
                          padding: EdgeInsets.only(
                              right: index < 7 ? DesktopTheme.spacingMd : 0),
                          child: MusicCard(
                            title: album.name,
                            subtitle: album.artistName ?? l10n.unknownArtist,
                            imageUrl: imageUrl,
                            size: 160,
                            onTap: () =>
                                NavigationService().navigateToAlbum(album),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (isSoundCloud &&
                    appState.artists.isEmpty &&
                    appState.tracks.isEmpty) ...[
                  const SizedBox(height: DesktopTheme.spacingXl * 2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DesktopTheme.spacingXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            size: 64,
                            color: DesktopTheme.textMuted,
                          ),
                          const SizedBox(height: DesktopTheme.spacingMd),
                          Text(
                            l10n.soundcloudFollowPrompt,
                            style: TextStyle(
                              fontSize: 16,
                              color: DesktopTheme.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DesktopTheme.spacingMd),
                          TextButton.icon(
                            onPressed: () =>
                                NavigationService().selectPage(1),
                            icon: const Icon(Icons.search_rounded),
                            label: Text(l10n.search),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final double width;

  const _LibraryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            color: DesktopTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
            border: Border.all(color: DesktopTheme.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: DesktopTheme.textPrimary),
              const SizedBox(height: DesktopTheme.spacingSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DesktopTheme.textPrimary,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
