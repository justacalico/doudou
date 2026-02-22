import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/layout/desktop_layout.dart';
import 'package:doudou/ui/pages/details/artist_detail.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';
import 'package:doudou/ui/widgets/detail_track_view.dart';

/// Home page built from reusable templates (page, section header, music cards, list tiles).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  String? _imageUrl(AppState appState, String? imageId) {
    return imageId != null ? appState.getImageUrl(imageId) : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DesktopTheme.spacingLg,
            DesktopTheme.spacingMd,
            DesktopTheme.spacingLg,
            0,
          ),
          child: appState.isLoading
              ? _loading(Theme.of(context))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: DesktopTheme.spacingMd),
                      _quickAccess(context, appState, l10n),
                      const SizedBox(height: DesktopTheme.spacingXl),
                      if (appState.albums.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentlyAddedAlbums,
                          subtitle: l10n.yourNewestAdditions,
                          useGradient: true,
                          onSeeAllPressed: () =>
                              NavigationService().selectPage(3),
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _albumRow(context, appState, l10n),
                        const SizedBox(height: DesktopTheme.spacingXl),
                      ],
                      if (appState.artists.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.yourArtists,
                          subtitle: l10n.browseByArtist,
                          onSeeAllPressed: () =>
                              NavigationService().selectPage(4),
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _artistRow(context, appState, l10n),
                        const SizedBox(height: DesktopTheme.spacingXl),
                      ],
                      if (appState.tracks.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentTracks,
                          subtitle: l10n.yourMusicCollection,
                        ),
                        const SizedBox(height: DesktopTheme.spacingMd),
                        _recentTracks(context, appState, l10n),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _loading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          Text(
            'Loading your music...',
            style: TextStyle(fontSize: 16, color: DesktopTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _quickAccess(
      BuildContext context, AppState appState, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: QuickAccessCard(
            title: 'Shuffle All',
            subtitle: l10n.countSongs(appState.tracks.length),
            icon: Icons.shuffle_rounded,
            color: DesktopTheme.playButtonGreen,
            onTap: () => appState.shuffleAllTracks(),
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: QuickAccessCard(
            title: 'Shuffle Favorites',
            subtitle: l10n.countSongs(
                appState.tracks.where((t) => t.isFavorite).length),
            icon: Icons.favorite_rounded,
            color: DesktopTheme.heartRed,
            onTap: () => appState.shuffleFavoriteTracks(),
          ),
        ),
      ],
    );
  }

  Widget _albumRow(
      BuildContext context, AppState appState, AppLocalizations l10n) {
    final list = appState.albums.take(10).toList();
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final album = list[index];
          return Padding(
            padding: EdgeInsets.only(
                right: index < list.length - 1 ? DesktopTheme.spacingMd : 0),
            child: MusicCard(
              title: album.name,
              subtitle: album.artistName ?? l10n.unknownArtist,
              imageUrl: _imageUrl(appState, album.imageUrl),
              size: 180,
              onTap: () => NavigationService().navigateToAlbum(album),
            ),
          );
        },
      ),
    );
  }

  Widget _artistRow(
      BuildContext context, AppState appState, AppLocalizations l10n) {
    final list = appState.artists.take(10).toList();
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final artist = list[index];
          return Padding(
            padding: EdgeInsets.only(
                right: index < list.length - 1 ? DesktopTheme.spacingMd : 0),
            child: MusicCard(
              title: artist.name,
              subtitle: l10n.artist,
              imageUrl: _imageUrl(appState, artist.imageUrl),
              size: 180,
              onTap: () => NavigationService().navigateToArtist(artist),
            ),
          );
        },
      ),
    );
  }

  Widget _recentTracks(
      BuildContext context, AppState appState, AppLocalizations l10n) {
    final tracks = appState.tracks.take(8).toList();
    return Column(
      children: tracks
          .map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: DesktopTheme.spacingSm),
              child: MusicListTile(
                title: track.name,
                subtitle:
                    '${track.artistName ?? l10n.unknownArtist} • ${track.albumName ?? l10n.unknownAlbum}',
                imageUrl: _imageUrl(appState, track.imageUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track.duration != null)
                      Text(
                        _formatDuration(track.duration!),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesktopTheme.textTertiary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    const SizedBox(width: DesktopTheme.spacingSm),
                    DesktopIconButton(
                      icon: Icons.more_horiz_rounded,
                      onPressed: () =>
                          _showTrackMoreMenu(context, track, appState),
                      size: 18,
                    ),
                  ],
                ),
                onTap: () {
                  final i = appState.tracks.indexOf(track);
                  if (i >= 0) appState.playPlaylist(appState.tracks, i);
                },
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _showTrackMoreMenu(
      BuildContext context, Track track, AppState appState) {
    final l10n = AppLocalizations.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              DesktopLayout.showAddToPlaylistDialog(context, track);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.add_circled,
                  color: CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 8),
                Text(l10n.addToPlaylist),
              ],
            ),
          ),
          if (track.albumId != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                try {
                  final album = appState.albums.firstWhere(
                    (a) => a.id == track.albumId,
                    orElse: () => throw StateError('not found'),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetailTrackView.album(album),
                    ),
                  );
                } catch (_) {}
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.music_albums,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.goToAlbum),
                ],
              ),
            ),
          if (track.artistName != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                try {
                  final artist = appState.artists.firstWhere(
                    (a) => a.name == track.artistName,
                    orElse: () => throw StateError('not found'),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailScreen(artist: artist),
                    ),
                  );
                } catch (_) {}
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.person,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.goToArtist),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }
}
