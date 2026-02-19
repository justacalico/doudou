import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../services/base_service.dart';
import '../layout/breakpoint.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/horizontal_card_scroll.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';
import '../widgets/section_header.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final st = appState.mediaServiceManager.currentServerType;
          final showAlbums = st != ServerType.soundcloud;
          final albumsIndex = 3;
          final artistsIndex = showAlbums ? 4 : 3;
          final songsIndex = showAlbums ? 5 : 4;
          final playlistsIndex = showAlbums ? 6 : 5;

          return PageTemplate(
            title: l10n.navLibrary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: l10n.libraryOverview,
                    subtitle: l10n.yourMusicCollection,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < kLayoutBreakpoint;
                      final tileWidth = narrow ? (constraints.maxWidth - AppTheme.spacingMd) / 2 : 160.0;
                      return Wrap(
                        spacing: AppTheme.spacingMd,
                        runSpacing: AppTheme.spacingMd,
                        children: [
                          if (showAlbums)
                            _LibraryTile(
                              icon: Icons.album_rounded,
                              label: l10n.albums,
                              count: appState.albums.length,
                              onTap: () => NavigationService().selectPage(albumsIndex),
                              width: tileWidth,
                            ),
                          _LibraryTile(
                            icon: Icons.person_rounded,
                            label: l10n.artists,
                            count: appState.artists.length,
                            onTap: () => NavigationService().selectPage(artistsIndex),
                            width: tileWidth,
                          ),
                          _LibraryTile(
                            icon: Icons.music_note_rounded,
                            label: l10n.songs,
                            count: appState.tracks.length,
                            onTap: () => NavigationService().selectPage(songsIndex),
                            width: tileWidth,
                          ),
                          _LibraryTile(
                            icon: Icons.queue_music_rounded,
                            label: l10n.playlists,
                            count: appState.playlists.length,
                            onTap: () => NavigationService().selectPage(playlistsIndex),
                            width: tileWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  if (showAlbums && appState.albums.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXl),
                    SectionHeader(
                      title: l10n.recentlyAddedAlbums,
                      onSeeAllPressed: () => NavigationService().selectPage(albumsIndex),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    HorizontalCardScroll(
                      itemCount: appState.albums.take(8).length,
                      itemWidth: 160,
                      height: 230,
                      itemBuilder: (context, i) {
                        final album = appState.albums[i];
                        final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
                        return MusicCard(
                          title: album.name,
                          subtitle: album.artistName ?? l10n.unknownArtist,
                          imageUrl: imageUrl,
                          size: 160,
                          onTap: () => NavigationService().navigateToAlbum(album),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
          );
        },
      ),
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
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.textMuted),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppTheme.textPrimary),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
