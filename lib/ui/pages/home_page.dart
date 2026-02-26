import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/layout/desktop_layout.dart';
import 'package:doudou/ui/pages/details/media_details.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

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
        final isYtMusic =
            appState.mediaServiceManager.currentServerType ==
            ServerType.youtubeMusic;
        if (isYtMusic) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              DesktopTheme.spacingLg,
              DesktopTheme.spacingLg,
              DesktopTheme.spacingLg,
              0,
            ),
            child: _ytFollowHintBody(context, appState, l10n),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DesktopTheme.spacingLg,
            DesktopTheme.spacingMd,
            DesktopTheme.spacingLg,
            0,
          ),
          child: appState.isLoading && !isYtMusic
              ? _loading(Theme.of(context))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: DesktopTheme.spacingMd),
                    _quickAccess(context, appState, l10n),
                    const SizedBox(height: DesktopTheme.spacingXl),
                    Expanded(child: _libraryHomeBody(context, appState, l10n)),
                  ],
                ),
        );
      },
    );
  }

  Widget _ytFollowHintBody(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final followedAlbums = appState.favoriteAlbums.length;
    final followedArtists = appState.favoriteArtists.length;
    final followedTracks = appState.favoriteTracks;

    if (followedAlbums > 0 || followedArtists > 0) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Following',
              subtitle:
                  '$followedArtists artists • $followedAlbums albums',
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            if (appState.favoriteArtists.isNotEmpty) ...[
              SectionHeader(
                title: l10n.artists,
                onSeeAllPressed: () => NavigationService().selectPage(4),
              ),
              const SizedBox(height: DesktopTheme.spacingSm),
              _artistRow(context, appState, l10n, appState.favoriteArtists),
              const SizedBox(height: DesktopTheme.spacingLg),
            ],
            if (appState.favoriteAlbums.isNotEmpty) ...[
              SectionHeader(
                title: l10n.albums,
                onSeeAllPressed: () => NavigationService().selectPage(3),
              ),
              const SizedBox(height: DesktopTheme.spacingSm),
              _albumRow(context, appState, l10n, appState.favoriteAlbums),
              const SizedBox(height: DesktopTheme.spacingLg),
            ],
            if (followedTracks.isNotEmpty) ...[
              SectionHeader(
                title: l10n.songs,
                onSeeAllPressed: () => NavigationService().selectPage(5),
              ),
              const SizedBox(height: DesktopTheme.spacingSm),
              _recentTracks(
                context,
                appState,
                l10n,
                followedTracks.take(15).toList(),
              ),
            ],
            const SizedBox(height: 120),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 72,
            color: DesktopTheme.textMuted,
          ),
          const SizedBox(height: DesktopTheme.spacingLg),
          Text(
            'YouTube Music home is follow-based',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: DesktopTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingSm),
          Text(
            'Use Search to find artists or albums, then follow them to get personalized content here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DesktopTheme.textSecondary),
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          Text(
            'Following: $followedArtists artists • $followedAlbums albums',
            style: TextStyle(fontSize: 13, color: DesktopTheme.textTertiary),
          ),
          const SizedBox(height: DesktopTheme.spacingXl),
          FilledButton.icon(
            onPressed: () => NavigationService().selectPage(1),
            icon: const Icon(Icons.search_rounded),
            label: Text(l10n.search),
          ),
        ],
      ),
    );
  }

  Widget _libraryHomeBody(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final continueListening = _pickVaried<Track>(
      appState.recentTracks,
      10,
      salt: 'continue',
      keyOf: (t) => t.id,
    );
    final basedOnFavorites = _pickTracksFromFavoriteArtists(appState);
    final featuredPlaylists = _pickVaried<Playlist>(
      appState.playlists,
      10,
      salt: 'playlists',
      keyOf: (p) => p.id,
    );
    final latestAlbums = _pickRecentAlbums(appState.albums, 10);
    final artistsToExplore = _pickVaried<Artist>(
      appState.artists,
      10,
      salt: 'artists',
      keyOf: (a) => a.id,
    );
    final freshPicks = _pickVaried<Track>(
      appState.tracks,
      10,
      salt: 'fresh',
      keyOf: (t) => t.id,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (continueListening.isNotEmpty) ...[
            SectionHeader(
              title: l10n.homeContinueListening,
              subtitle: l10n.homeContinueListeningSubtitle,
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _trackRow(context, appState, l10n, continueListening),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],
          if (basedOnFavorites.isNotEmpty) ...[
            SectionHeader(
              title: l10n.homeBecauseYouLikeArtists,
              subtitle: l10n.homeBecauseYouLikeArtistsSubtitle,
              onSeeAllPressed: () => NavigationService().selectPage(5),
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _trackRow(context, appState, l10n, basedOnFavorites),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],
          if (featuredPlaylists.isNotEmpty) ...[
            SectionHeader(
              title: l10n.playlists,
              subtitle: l10n.homePlaylistsSubtitle,
              onSeeAllPressed: () => NavigationService().selectPage(6),
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _playlistRow(context, appState, featuredPlaylists),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],
          if (latestAlbums.isNotEmpty) ...[
            SectionHeader(
              title: l10n.recentlyAddedAlbums,
              subtitle: l10n.yourNewestAdditions,
              useGradient: true,
              onSeeAllPressed: () => NavigationService().selectPage(3),
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _albumRow(context, appState, l10n, latestAlbums),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],
          if (artistsToExplore.isNotEmpty) ...[
            SectionHeader(
              title: l10n.yourArtists,
              subtitle: l10n.homeArtistsSubtitle,
              onSeeAllPressed: () => NavigationService().selectPage(4),
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _artistRow(context, appState, l10n, artistsToExplore),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],
          if (freshPicks.isNotEmpty) ...[
            SectionHeader(
              title: l10n.homeFreshPicks,
              subtitle: l10n.yourMusicCollection,
              onSeeAllPressed: () => NavigationService().selectPage(5),
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            _recentTracks(context, appState, l10n, freshPicks),
          ],
          if (continueListening.isEmpty &&
              basedOnFavorites.isEmpty &&
              featuredPlaylists.isEmpty &&
              latestAlbums.isEmpty &&
              artistsToExplore.isEmpty &&
              freshPicks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                l10n.homeEmptyLibraryMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: DesktopTheme.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  List<T> _pickVaried<T>(
    List<T> source,
    int count, {
    required String salt,
    required String Function(T) keyOf,
  }) {
    if (source.isEmpty || count <= 0) return const [];
    final seed = DateTime.now().toUtc().difference(DateTime.utc(2024)).inDays;
    final sorted = List<T>.from(source)
      ..sort((a, b) {
        final ah = Object.hash(seed, salt, keyOf(a));
        final bh = Object.hash(seed, salt, keyOf(b));
        return ah.compareTo(bh);
      });
    return sorted.take(count).toList();
  }

  List<Album> _pickRecentAlbums(List<Album> albums, int count) {
    if (albums.isEmpty || count <= 0) return const [];
    final withDate = albums.where((a) => a.dateCreated != null).toList()
      ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    if (withDate.length >= count) return withDate.take(count).toList();
    final remainingCount = count - withDate.length;
    final remaining = albums.where((a) => a.dateCreated == null).toList();
    return [
      ...withDate,
      ..._pickVaried<Album>(
        remaining,
        remainingCount,
        salt: 'albums-fallback',
        keyOf: (a) => a.id,
      ),
    ];
  }

  List<Track> _pickTracksFromFavoriteArtists(AppState appState) {
    final favoriteArtistNames = appState.favoriteTracks
        .map((t) => t.artistName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet();
    if (favoriteArtistNames.isEmpty) return const [];
    final matching = appState.tracks
        .where(
          (t) =>
              t.artistName != null &&
              favoriteArtistNames.contains(t.artistName) &&
              !t.isFavorite,
        )
        .toList();
    if (matching.isEmpty) {
      return _pickVaried<Track>(
        appState.favoriteTracks,
        10,
        salt: 'favorite-fallback',
        keyOf: (t) => t.id,
      );
    }
    return _pickVaried<Track>(
      matching,
      10,
      salt: 'favorite-artists',
      keyOf: (t) => t.id,
    );
  }

  Widget _trackRow(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    List<Track> tracks,
  ) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final imageUrl = _imageUrl(appState, track.imageUrl);
          return KeyedSubtree(
            key: ValueKey(track.id),
            child: Padding(
              padding: EdgeInsets.only(
                right: index < tracks.length - 1 ? DesktopTheme.spacingMd : 0,
              ),
              child: SizedBox(
                width: 280,
                child: MusicListTile(
                title: track.name,
                subtitle: track.artistName ?? l10n.unknownArtist,
                imageUrl: imageUrl,
                onSecondaryTap: () =>
                    _showTrackMoreMenu(context, track, appState),
                onTap: () => appState.playPlaylist(tracks, index),
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _playlistRow(
    BuildContext context,
    AppState appState,
    List<Playlist> playlists,
  ) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final imageUrl =
              playlist.imageUrl ??
              appState.mediaServiceManager.getImageUrl(playlist.id);
          return KeyedSubtree(
            key: ValueKey(playlist.id),
            child: Padding(
              padding: EdgeInsets.only(
                right: index < playlists.length - 1 ? DesktopTheme.spacingMd : 0,
              ),
              child: MusicCard(
                title: playlist.name,
                subtitle: l10n.countSongs(playlist.trackCount),
                imageUrl: imageUrl,
                size: 180,
                onTap: () => NavigationService().navigateToPlaylist(playlist),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loading(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
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
            l10n.loadingYourMusicLibrary,
            style: TextStyle(fontSize: 16, color: DesktopTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _quickAccess(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: QuickAccessCard(
            title: l10n.shuffleAll,
            subtitle: l10n.countSongs(appState.tracks.length),
            icon: Icons.shuffle_rounded,
            color: DesktopTheme.playButtonGreen,
            onTap: () => appState.shuffleAllTracks(),
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: QuickAccessCard(
            title: l10n.shuffleFavorites,
            subtitle: l10n.countSongs(appState.favoriteTracks.length),
            icon: Icons.favorite_rounded,
            color: DesktopTheme.heartRed,
            onTap: () => appState.shuffleFavoriteTracks(),
          ),
        ),
      ],
    );
  }

  Widget _albumRow(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    List<Album> list,
  ) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final album = list[index];
          return KeyedSubtree(
            key: ValueKey(album.id),
            child: Padding(
              padding: EdgeInsets.only(
                right: index < list.length - 1 ? DesktopTheme.spacingMd : 0,
              ),
              child: MusicCard(
                title: album.name,
                subtitle: album.artistName ?? l10n.unknownArtist,
                imageUrl: _imageUrl(appState, album.imageUrl),
                size: 180,
                onTap: () => NavigationService().navigateToAlbum(album),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _artistRow(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    List<Artist> list,
  ) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final artist = list[index];
          return KeyedSubtree(
            key: ValueKey(artist.id),
            child: Padding(
              padding: EdgeInsets.only(
                right: index < list.length - 1 ? DesktopTheme.spacingMd : 0,
              ),
              child: MusicCard(
                title: artist.name,
                subtitle: l10n.artist,
                imageUrl: _imageUrl(appState, artist.imageUrl),
                size: 180,
                onTap: () => NavigationService().navigateToArtist(artist),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recentTracks(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    List<Track> tracks,
  ) {
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
                onSecondaryTap: () =>
                    _showTrackMoreMenu(context, track, appState),
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
    BuildContext context,
    Track track,
    AppState appState,
  ) {
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
                      builder: (_) => MediaDetailsPage.album(album: album),
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
                      builder: (_) => MediaDetailsPage.artist(artist: artist),
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
