import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../../models/download_models.dart';
import '../../../models/jellyfin_models.dart';
import '../../../providers/app_state.dart';
import 'adaptive_shell_state.dart';
import 'media_detail_view.dart';

String labelForSection(BuildContext context, AppShellSection section) {
  final l10n = context.l10n;
  switch (section) {
    case AppShellSection.home:
      return l10n.navHome;
    case AppShellSection.tracks:
      return l10n.navTracks;
    case AppShellSection.albums:
      return l10n.navAlbums;
    case AppShellSection.artists:
      return l10n.navArtists;
    case AppShellSection.playlists:
      return l10n.navPlaylists;
    case AppShellSection.downloads:
      return l10n.navDownloads;
    case AppShellSection.favorites:
      return l10n.navFavorites;
    case AppShellSection.settings:
      return l10n.navSettings;
  }
}

IconData materialIconForSection(AppShellSection section) {
  switch (section) {
    case AppShellSection.home:
      return Icons.home_rounded;
    case AppShellSection.tracks:
      return Icons.music_note_rounded;
    case AppShellSection.albums:
      return Icons.album_rounded;
    case AppShellSection.artists:
      return Icons.people_alt_rounded;
    case AppShellSection.playlists:
      return Icons.playlist_play_rounded;
    case AppShellSection.downloads:
      return Icons.download_rounded;
    case AppShellSection.favorites:
      return Icons.favorite_rounded;
    case AppShellSection.settings:
      return Icons.settings_rounded;
  }
}

IconData cupertinoIconForSection(AppShellSection section) {
  switch (section) {
    case AppShellSection.home:
      return CupertinoIcons.house_fill;
    case AppShellSection.tracks:
      return CupertinoIcons.music_note_list;
    case AppShellSection.albums:
      return CupertinoIcons.rectangle_stack_fill;
    case AppShellSection.artists:
      return CupertinoIcons.person_2_fill;
    case AppShellSection.playlists:
      return CupertinoIcons.music_note;
    case AppShellSection.downloads:
      return CupertinoIcons.arrow_down_circle_fill;
    case AppShellSection.favorites:
      return CupertinoIcons.heart_fill;
    case AppShellSection.settings:
      return CupertinoIcons.settings_solid;
  }
}

class AdaptiveShellContent extends StatelessWidget {
  const AdaptiveShellContent({
    super.key,
    required this.section,
    required this.isCupertino,
  });

  final AppShellSection section;
  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AppShellSection.home:
        return _HomeSection(isCupertino: isCupertino);
      case AppShellSection.tracks:
        return _TracksSection(isCupertino: isCupertino);
      case AppShellSection.albums:
        return _AlbumsSection(isCupertino: isCupertino);
      case AppShellSection.artists:
        return _ArtistsSection(isCupertino: isCupertino);
      case AppShellSection.playlists:
        return _PlaylistsSection(isCupertino: isCupertino);
      case AppShellSection.downloads:
        return _DownloadsSection(isCupertino: isCupertino);
      case AppShellSection.favorites:
        return _FavoritesSection(isCupertino: isCupertino);
      case AppShellSection.settings:
        return _SettingsSection(isCupertino: isCupertino);
    }
  }
}

class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key, required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final currentTrack = appState.audioHandler?.currentTrack;
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        final isPlaying = appState.audioHandler?.userIntendedPlaying ?? false;
        final canSkipNext = appState.audioHandler?.hasNext ?? false;
        final canSkipPrevious = appState.audioHandler?.hasPrevious ?? false;
        final duration = appState.audioHandler?.duration ?? Duration.zero;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: isCupertino
                ? CupertinoColors.systemBackground.resolveFrom(context)
                : Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: isCupertino
                    ? CupertinoColors.separator.resolveFrom(context)
                    : Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 460;

                      return Row(
                        children: [
                          _MediaArtwork(
                            imageId:
                                currentTrack.imageUrl ?? currentTrack.albumId,
                            size: 42,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentTrack.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  currentTrack.artistName ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCupertino
                                        ? CupertinoColors.secondaryLabel
                                              .resolveFrom(context)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!compact)
                            _AdaptiveIconButton(
                              isCupertino: isCupertino,
                              onPressed: canSkipPrevious
                                  ? () => appState.skipToPrevious()
                                  : null,
                              icon: isCupertino
                                  ? CupertinoIcons.backward_fill
                                  : Icons.skip_previous_rounded,
                            ),
                          _AdaptiveIconButton(
                            isCupertino: isCupertino,
                            onPressed: appState.playPause,
                            icon: isPlaying
                                ? (isCupertino
                                      ? CupertinoIcons.pause_fill
                                      : Icons.pause_rounded)
                                : (isCupertino
                                      ? CupertinoIcons.play_fill
                                      : Icons.play_arrow_rounded),
                          ),
                          _AdaptiveIconButton(
                            isCupertino: isCupertino,
                            onPressed: canSkipNext
                                ? () => appState.skipToNext()
                                : null,
                            icon: isCupertino
                                ? CupertinoIcons.forward_fill
                                : Icons.skip_next_rounded,
                          ),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<Duration>(
                    stream: appState.positionStream,
                    initialData: Duration.zero,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final maxMs = duration.inMilliseconds <= 0
                          ? 1.0
                          : duration.inMilliseconds.toDouble();
                      final clamped = position.inMilliseconds
                          .clamp(
                            0,
                            duration.inMilliseconds <= 0
                                ? 1
                                : duration.inMilliseconds,
                          )
                          .toDouble();

                      if (isCupertino) {
                        return CupertinoSlider(
                          value: clamped,
                          min: 0,
                          max: maxMs,
                          onChanged: (value) {
                            appState.seekTo(
                              Duration(milliseconds: value.round()),
                            );
                          },
                        );
                      }

                      return Slider(
                        value: clamped,
                        min: 0,
                        max: maxMs,
                        onChanged: (value) {
                          appState.seekTo(
                            Duration(milliseconds: value.round()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AdaptiveShellState>(
      builder: (context, appState, shellState, _) {
        final l10n = context.l10n;
        final isMobileLayout = MediaQuery.sizeOf(context).width < 920;

        final tracks = appState.recentTracks.isNotEmpty
            ? appState.recentTracks
            : appState.tracks.take(12).toList();

        return ListView(
          key: const PageStorageKey<String>('section-home-list'),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              isCupertino: isCupertino,
              title: l10n.navHome,
              subtitle: appState.isOfflineMode
                  ? l10n.offlineModeDownloadsOnly
                  : l10n.libraryOverview,
            ),
            if (isMobileLayout) ...[
              const SizedBox(height: 10),
              _HomeShuffleActions(
                isCupertino: isCupertino,
                allLoading: appState.isLoadingAllTracks,
                favoritesLoading: appState.isLoadingFavorites,
                onShuffleAll: appState.shuffleAllTracks,
                onShuffleFavorites: appState.shuffleFavoriteTracks,
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width > 1100
                    ? 4
                    : width > 760
                    ? 3
                    : 2;
                final cardWidth = (width - ((columns - 1) * 12)) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: l10n.albums,
                        value: l10n.albumsCount(appState.albums.length),
                        icon: isCupertino
                            ? CupertinoIcons.rectangle_stack_fill
                            : Icons.album_rounded,
                        isCupertino: isCupertino,
                        onTap: () =>
                            shellState.selectSection(AppShellSection.albums),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: l10n.artists,
                        value: l10n.artistsCount(appState.artists.length),
                        icon: isCupertino
                            ? CupertinoIcons.person_2_fill
                            : Icons.people_alt_rounded,
                        isCupertino: isCupertino,
                        onTap: () =>
                            shellState.selectSection(AppShellSection.artists),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: l10n.navTracks,
                        value: l10n.tracksCount(appState.tracks.length),
                        icon: isCupertino
                            ? CupertinoIcons.music_note_list
                            : Icons.music_note_rounded,
                        isCupertino: isCupertino,
                        onTap: () =>
                            shellState.selectSection(AppShellSection.tracks),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: l10n.playlists,
                        value: l10n.playlistsCount(appState.playlists.length),
                        icon: isCupertino
                            ? CupertinoIcons.music_note
                            : Icons.playlist_play_rounded,
                        isCupertino: isCupertino,
                        onTap: () =>
                            shellState.selectSection(AppShellSection.playlists),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              isCupertino: isCupertino,
              title: l10n.libraryRecent,
              subtitle: l10n.nowPlaying,
            ),
            const SizedBox(height: 10),
            if (tracks.isEmpty)
              _EmptyState(
                isCupertino: isCupertino,
                title: l10n.libraryAppearsEmpty,
                subtitle: l10n.libraryEmpty,
              )
            else
              ...tracks.map(
                (track) => _TrackTile(
                  track: track,
                  isCupertino: isCupertino,
                  onPlay: () => appState.playTrack(track),
                  onFavorite: () => appState.toggleFavorite(track),
                  onQueue: () => appState.addToQueue(track),
                  onDownload: () =>
                      appState.downloadService.downloadTrack(track),
                  onOpenAlbum: () => _openAlbumFromTrack(
                    context,
                    appState,
                    track,
                    isCupertino,
                  ),
                  onOpenArtist: () => _openArtistFromName(
                    context,
                    appState,
                    track.artistName,
                    isCupertino,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TracksSection extends StatelessWidget {
  const _TracksSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AdaptiveShellState>(
      builder: (context, appState, shellState, _) {
        final l10n = context.l10n;
        final query = shellState.trackSearchQuery.trim().toLowerCase();

        final tracks = query.isEmpty
            ? appState.tracks
            : appState.tracks.where((track) {
                final name = track.name.toLowerCase();
                final artist = (track.artistName ?? '').toLowerCase();
                final album = (track.albumName ?? '').toLowerCase();
                return name.contains(query) ||
                    artist.contains(query) ||
                    album.contains(query);
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _SectionTitle(
                isCupertino: isCupertino,
                title: l10n.navTracks,
                subtitle: l10n.tracksCount(tracks.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionSearchField(
                isCupertino: isCupertino,
                initialValue: shellState.trackSearchQuery,
                hintText: l10n.searchPlaceholder,
                onChanged: shellState.setTrackSearchQuery,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tracks.isEmpty
                  ? _EmptyState(
                      isCupertino: isCupertino,
                      title: l10n.libraryAppearsEmpty,
                      subtitle: l10n.searchDescription,
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>('section-tracks-list'),
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return _TrackTile(
                          track: track,
                          isCupertino: isCupertino,
                          onPlay: () => appState.playTrack(track),
                          onFavorite: () => appState.toggleFavorite(track),
                          onQueue: () => appState.addToQueue(track),
                          onDownload: () =>
                              appState.downloadService.downloadTrack(track),
                          onOpenAlbum: () => _openAlbumFromTrack(
                            context,
                            appState,
                            track,
                            isCupertino,
                          ),
                          onOpenArtist: () => _openArtistFromName(
                            context,
                            appState,
                            track.artistName,
                            isCupertino,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AlbumsSection extends StatelessWidget {
  const _AlbumsSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AdaptiveShellState>(
      builder: (context, appState, shellState, _) {
        final l10n = context.l10n;
        final query = shellState.albumSearchQuery.trim().toLowerCase();
        final albums = query.isEmpty
            ? appState.albums
            : appState.albums
                  .where(
                    (album) =>
                        album.name.toLowerCase().contains(query) ||
                        (album.artistName ?? '').toLowerCase().contains(query),
                  )
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _SectionTitle(
                isCupertino: isCupertino,
                title: l10n.navAlbums,
                subtitle: l10n.albumsCount(albums.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionSearchField(
                isCupertino: isCupertino,
                initialValue: shellState.albumSearchQuery,
                hintText: l10n.searchAlbums,
                onChanged: shellState.setAlbumSearchQuery,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width > 1200
                      ? 6
                      : width > 900
                      ? 5
                      : width > 700
                      ? 4
                      : width > 500
                      ? 3
                      : 2;

                  if (albums.isEmpty) {
                    return _EmptyState(
                      isCupertino: isCupertino,
                      title: l10n.libraryAppearsEmpty,
                      subtitle: l10n.albumsWillAppear,
                    );
                  }

                  return GridView.builder(
                    key: const PageStorageKey<String>('section-albums-grid'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _AlbumCard(
                        album: album,
                        isCupertino: isCupertino,
                        onTap: () => openAlbumDetailView(
                          context,
                          album: album,
                          isCupertino: isCupertino,
                        ),
                        onPlay: () async {
                          final tracks = await appState.getAlbumTracks(
                            album.id,
                          );
                          if (tracks.isNotEmpty) {
                            await appState.playPlaylist(tracks, 0);
                          }
                        },
                        onFavorite: () => appState.toggleAlbumFavorite(album),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArtistsSection extends StatelessWidget {
  const _ArtistsSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AdaptiveShellState>(
      builder: (context, appState, shellState, _) {
        final l10n = context.l10n;
        final query = shellState.artistSearchQuery.trim().toLowerCase();
        final artists = query.isEmpty
            ? appState.artists
            : appState.artists
                  .where((artist) => artist.name.toLowerCase().contains(query))
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _SectionTitle(
                isCupertino: isCupertino,
                title: l10n.navArtists,
                subtitle: l10n.artistsCount(artists.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionSearchField(
                isCupertino: isCupertino,
                initialValue: shellState.artistSearchQuery,
                hintText: l10n.searchArtists,
                onChanged: shellState.setArtistSearchQuery,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: artists.isEmpty
                  ? _EmptyState(
                      isCupertino: isCupertino,
                      title: l10n.libraryAppearsEmpty,
                      subtitle: l10n.artistsWillAppear,
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>('section-artists-list'),
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      itemCount: artists.length,
                      itemBuilder: (context, index) {
                        final artist = artists[index];
                        return _AdaptiveTile(
                          isCupertino: isCupertino,
                          title: artist.name,
                          subtitle: l10n.artists,
                          leading: _MediaArtwork(imageId: artist.imageUrl),
                          onTap: () => openArtistDetailView(
                            context,
                            artist: artist,
                            isCupertino: isCupertino,
                          ),
                          trailing: _AdaptiveIconButton(
                            isCupertino: isCupertino,
                            onPressed: () => appState.playArtistTracks(artist),
                            icon: isCupertino
                                ? CupertinoIcons.play_fill
                                : Icons.play_arrow_rounded,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistsSection extends StatelessWidget {
  const _PlaylistsSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AdaptiveShellState>(
      builder: (context, appState, shellState, _) {
        final l10n = context.l10n;
        final query = shellState.playlistSearchQuery.trim().toLowerCase();

        final playlists = query.isEmpty
            ? appState.playlists
            : appState.playlists
                  .where(
                    (playlist) => playlist.name.toLowerCase().contains(query),
                  )
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _SectionTitle(
                isCupertino: isCupertino,
                title: l10n.navPlaylists,
                subtitle: l10n.playlistsCount(playlists.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionSearchField(
                isCupertino: isCupertino,
                initialValue: shellState.playlistSearchQuery,
                hintText: l10n.searchPlaylists,
                onChanged: shellState.setPlaylistSearchQuery,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: playlists.isEmpty
                  ? _EmptyState(
                      isCupertino: isCupertino,
                      title: l10n.libraryAppearsEmpty,
                      subtitle: l10n.playlists,
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>(
                        'section-playlists-list',
                      ),
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return _AdaptiveTile(
                          isCupertino: isCupertino,
                          title: playlist.name,
                          subtitle: l10n.playlistTrackCount(
                            playlist.trackCount,
                          ),
                          leading: _MediaArtwork(imageId: playlist.imageUrl),
                          onTap: () => openPlaylistDetailView(
                            context,
                            playlist: playlist,
                            isCupertino: isCupertino,
                          ),
                          trailing: _AdaptiveIconButton(
                            isCupertino: isCupertino,
                            onPressed: () async {
                              final tracks = await appState.getPlaylistTracks(
                                playlist.id,
                              );
                              if (tracks.isNotEmpty) {
                                await appState.playPlaylist(tracks, 0);
                              }
                            },
                            icon: isCupertino
                                ? CupertinoIcons.play_fill
                                : Icons.play_arrow_rounded,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final l10n = context.l10n;
        final downloadService = appState.downloadService;
        final downloaded = downloadService.downloadedTracks.values.toList();
        final tasks = downloadService.downloadTasks;
        final tracksById = {
          for (final track in appState.tracks) track.id: track,
        };

        return ListView(
          key: const PageStorageKey<String>('section-downloads-list'),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              isCupertino: isCupertino,
              title: l10n.navDownloads,
              subtitle:
                  '${downloaded.length} saved • ${tasks.where((task) => task.status == DownloadStatus.downloading).length} active',
              trailing: _ActionButton(
                isCupertino: isCupertino,
                onPressed: downloadService.clearAllDownloads,
                icon: isCupertino
                    ? CupertinoIcons.trash
                    : Icons.delete_sweep_rounded,
                label: l10n.delete,
              ),
            ),
            const SizedBox(height: 10),
            if (tasks.isNotEmpty) ...[
              _SectionTitle(
                isCupertino: isCupertino,
                title: l10n.loading,
                subtitle: l10n.downloadsContinueInBackground,
              ),
              const SizedBox(height: 8),
              ...tasks.map(
                (task) => _AdaptiveTile(
                  isCupertino: isCupertino,
                  title: task.trackName,
                  subtitle:
                      '${(task.progress * 100).toStringAsFixed(0)}% • ${task.status.name}',
                  trailing: _AdaptiveIconButton(
                    isCupertino: isCupertino,
                    onPressed: () =>
                        downloadService.cancelDownload(task.trackId),
                    icon: isCupertino
                        ? CupertinoIcons.xmark_circle_fill
                        : Icons.cancel_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SectionTitle(
              isCupertino: isCupertino,
              title: l10n.downloads,
              subtitle: '${downloaded.length} ${l10n.trackPlural}',
            ),
            const SizedBox(height: 8),
            if (downloaded.isEmpty)
              _EmptyState(
                isCupertino: isCupertino,
                title: l10n.downloads,
                subtitle: l10n.libraryAppearsEmpty,
              )
            else
              ...downloaded.map((downloadedTrack) {
                final track = tracksById[downloadedTrack.trackId];
                return _AdaptiveTile(
                  isCupertino: isCupertino,
                  title: track?.name ?? downloadedTrack.trackId,
                  subtitle: track?.artistName ?? '-',
                  leading: _MediaArtwork(imageId: track?.imageUrl),
                  trailing: _AdaptiveIconButton(
                    isCupertino: isCupertino,
                    onPressed: () =>
                        downloadService.deleteDownload(downloadedTrack.trackId),
                    icon: isCupertino
                        ? CupertinoIcons.trash
                        : Icons.delete_outline_rounded,
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final l10n = context.l10n;
        final favorites = appState.favoriteTracks;

        return ListView(
          key: const PageStorageKey<String>('section-favorites-list'),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              isCupertino: isCupertino,
              title: l10n.navFavorites,
              subtitle: l10n.tracksCount(favorites.length),
            ),
            const SizedBox(height: 8),
            if (favorites.isEmpty)
              _EmptyState(
                isCupertino: isCupertino,
                title: l10n.navFavorites,
                subtitle: l10n.libraryAppearsEmpty,
              )
            else
              ...favorites.map(
                (track) => _TrackTile(
                  track: track,
                  isCupertino: isCupertino,
                  onPlay: () => appState.playTrack(track),
                  onFavorite: () => appState.toggleFavorite(track),
                  onQueue: () => appState.addToQueue(track),
                  onDownload: () =>
                      appState.downloadService.downloadTrack(track),
                  onOpenAlbum: () => _openAlbumFromTrack(
                    context,
                    appState,
                    track,
                    isCupertino,
                  ),
                  onOpenArtist: () => _openArtistFromName(
                    context,
                    appState,
                    track.artistName,
                    isCupertino,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({required this.isCupertino});

  final bool isCupertino;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool _working = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_working) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final l10n = context.l10n;
        final themeMode = appState.themeMode;
        final uiMode = appState.uiMode;
        final locale = appState.locale;

        final languageValue = locale == null
            ? 'system'
            : locale.languageCode == 'ru'
            ? 'ru'
            : locale.languageCode == 'zh'
            ? 'zh'
            : 'en';

        return ListView(
          key: const PageStorageKey<String>('section-settings-list'),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              isCupertino: widget.isCupertino,
              title: l10n.settings,
              subtitle: l10n.connectionStatus,
              trailing: _working
                  ? (widget.isCupertino
                        ? const CupertinoActivityIndicator()
                        : const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                  : null,
            ),
            const SizedBox(height: 8),
            _AdaptivePanel(
              isCupertino: widget.isCupertino,
              child: Column(
                children: [
                  _SettingRow(
                    isCupertino: widget.isCupertino,
                    label: 'UI style',
                    control: _UiModeSelector(
                      isCupertino: widget.isCupertino,
                      value: uiMode,
                      onChanged: (mode) {
                        if (mode != null) {
                          _runAction(() => appState.setUiMode(mode));
                        }
                      },
                    ),
                  ),
                  _SettingRow(
                    isCupertino: widget.isCupertino,
                    label: l10n.appTheme,
                    control: _ThemeSelector(
                      isCupertino: widget.isCupertino,
                      value: themeMode,
                      onChanged: (mode) {
                        if (mode != null) {
                          _runAction(() => appState.setThemeMode(mode));
                        }
                      },
                    ),
                  ),
                  _SettingRow(
                    isCupertino: widget.isCupertino,
                    label: l10n.language,
                    control: _LanguageSelector(
                      isCupertino: widget.isCupertino,
                      value: languageValue,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        Locale? next;
                        if (value == 'en') {
                          next = const Locale('en');
                        } else if (value == 'ru') {
                          next = const Locale('ru');
                        } else if (value == 'zh') {
                          next = const Locale('zh');
                        }

                        _runAction(() => appState.setLocale(next));
                      },
                    ),
                  ),
                  _SettingRow(
                    isCupertino: widget.isCupertino,
                    label: l10n.accentColor,
                    control: _AccentSelector(
                      isCupertino: widget.isCupertino,
                      selected: appState.accentColor,
                      onSelected: (color) {
                        _runAction(() => appState.setAccentColor(color));
                      },
                    ),
                  ),
                  _SettingSwitch(
                    isCupertino: widget.isCupertino,
                    label: l10n.showAlbumArtSidebar,
                    value: appState.showAlbumArtEnabled,
                    onChanged: (value) {
                      _runAction(() => appState.toggleShowAlbumArt(value));
                    },
                  ),
                  _SettingSwitch(
                    isCupertino: widget.isCupertino,
                    label: l10n.dynamicIslePlayer,
                    value: appState.useDynamicIsle,
                    onChanged: (value) {
                      _runAction(() => appState.toggleDynamicIsle(value));
                    },
                  ),
                  _SettingSwitch(
                    isCupertino: widget.isCupertino,
                    label: l10n.enableLogging,
                    value: appState.loggingEnabled,
                    onChanged: (value) {
                      _runAction(() => appState.toggleLogging(value));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AdaptivePanel(
              isCupertino: widget.isCupertino,
              child: Column(
                children: [
                  _ActionListTile(
                    isCupertino: widget.isCupertino,
                    label: l10n.refreshLibrary,
                    icon: widget.isCupertino
                        ? CupertinoIcons.refresh
                        : Icons.refresh_rounded,
                    onTap: () => _runAction(appState.refreshLibraryData),
                  ),
                  _ActionListTile(
                    isCupertino: widget.isCupertino,
                    label: l10n.cleanExpiredCache,
                    icon: widget.isCupertino
                        ? CupertinoIcons.trash
                        : Icons.auto_delete_rounded,
                    onTap: () => _runAction(appState.cleanupExpiredCache),
                  ),
                  _ActionListTile(
                    isCupertino: widget.isCupertino,
                    label: l10n.clearImageCache,
                    icon: widget.isCupertino
                        ? CupertinoIcons.photo
                        : Icons.image_not_supported_rounded,
                    onTap: () => _runAction(appState.clearImageCache),
                  ),
                  _ActionListTile(
                    isCupertino: widget.isCupertino,
                    label: l10n.clearAllCache,
                    icon: widget.isCupertino
                        ? CupertinoIcons.trash_fill
                        : Icons.delete_forever_rounded,
                    onTap: () => _runAction(appState.clearAllCache),
                  ),
                  _ActionListTile(
                    isCupertino: widget.isCupertino,
                    label: l10n.signOut,
                    icon: widget.isCupertino
                        ? CupertinoIcons.square_arrow_left
                        : Icons.logout_rounded,
                    danger: true,
                    onTap: () => _runAction(appState.logout),
                  ),
                ],
              ),
            ),
            if (appState.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.errorOccurred(appState.errorMessage!),
                style: TextStyle(
                  color: widget.isCupertino
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.isCupertino,
    required this.value,
    required this.onChanged,
  });

  final bool isCupertino;
  final ThemeMode value;
  final ValueChanged<ThemeMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isCupertino) {
      return CupertinoSlidingSegmentedControl<ThemeMode>(
        groupValue: value,
        children: {
          ThemeMode.system: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(l10n.systemDefault),
          ),
          ThemeMode.light: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(l10n.light),
          ),
          ThemeMode.dark: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(l10n.dark),
          ),
        },
        onValueChanged: onChanged,
      );
    }

    return DropdownButton<ThemeMode>(
      value: value,
      onChanged: onChanged,
      items: [
        DropdownMenuItem(
          value: ThemeMode.system,
          child: Text(l10n.systemDefault),
        ),
        DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.light)),
        DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.dark)),
      ],
    );
  }
}

class _UiModeSelector extends StatelessWidget {
  const _UiModeSelector({
    required this.isCupertino,
    required this.value,
    required this.onChanged,
  });

  final bool isCupertino;
  final AppUiMode value;
  final ValueChanged<AppUiMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoSlidingSegmentedControl<AppUiMode>(
        groupValue: value,
        children: const {
          AppUiMode.system: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('System'),
          ),
          AppUiMode.material: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Material'),
          ),
          AppUiMode.cupertino: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Cupertino'),
          ),
        },
        onValueChanged: onChanged,
      );
    }

    return DropdownButton<AppUiMode>(
      value: value,
      onChanged: onChanged,
      items: const [
        DropdownMenuItem(value: AppUiMode.system, child: Text('System')),
        DropdownMenuItem(value: AppUiMode.material, child: Text('Material')),
        DropdownMenuItem(value: AppUiMode.cupertino, child: Text('Cupertino')),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.isCupertino,
    required this.value,
    required this.onChanged,
  });

  final bool isCupertino;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      'system': l10n.systemLanguage,
      'en': 'English',
      'ru': 'Русский',
      'zh': '中文',
    };

    if (isCupertino) {
      return CupertinoSlidingSegmentedControl<String>(
        groupValue: value,
        children: {
          for (final entry in labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(entry.value),
            ),
        },
        onValueChanged: onChanged,
      );
    }

    return DropdownButton<String>(
      value: value,
      onChanged: onChanged,
      items: labels.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
    );
  }
}

class _AccentSelector extends StatelessWidget {
  const _AccentSelector({
    required this.isCupertino,
    required this.selected,
    required this.onSelected,
  });

  final bool isCupertino;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.red,
      Colors.green,
      Colors.indigo,
      Colors.pink,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final selectedColor = selected.toARGB32() == color.toARGB32();

        return GestureDetector(
          onTap: () => onSelected(color),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedColor
                    ? (isCupertino
                          ? CupertinoColors.label.resolveFrom(context)
                          : Theme.of(context).colorScheme.onSurface)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.isCupertino,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final bool isCupertino;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: isCupertino
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );

        if (trailing == null) {
          return titleBlock;
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: trailing!),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            Flexible(child: trailing!),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.isCupertino,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isCupertino;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isCupertino
              ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCupertino
                            ? CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              )
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return GestureDetector(onTap: onTap, child: card);
  }
}

class _HomeShuffleActions extends StatelessWidget {
  const _HomeShuffleActions({
    required this.isCupertino,
    required this.allLoading,
    required this.favoritesLoading,
    required this.onShuffleAll,
    required this.onShuffleFavorites,
  });

  final bool isCupertino;
  final bool allLoading;
  final bool favoritesLoading;
  final Future<void> Function() onShuffleAll;
  final Future<void> Function() onShuffleFavorites;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actionsLocked = allLoading || favoritesLoading;
    final allIcon = isCupertino
        ? CupertinoIcons.shuffle
        : Icons.shuffle_rounded;
    final favoritesIcon = isCupertino
        ? CupertinoIcons.heart_fill
        : Icons.favorite_rounded;

    final shuffleAllButton = _AsyncActionButton(
      isCupertino: isCupertino,
      icon: allIcon,
      label: l10n.shuffleAll,
      loading: allLoading,
      onPressed: actionsLocked ? null : onShuffleAll,
    );
    final shuffleFavoritesButton = _AsyncActionButton(
      isCupertino: isCupertino,
      icon: favoritesIcon,
      label: l10n.shuffleFavorites,
      loading: favoritesLoading,
      onPressed: actionsLocked ? null : onShuffleFavorites,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              shuffleAllButton,
              const SizedBox(height: 8),
              shuffleFavoritesButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: shuffleAllButton),
            const SizedBox(width: 8),
            Expanded(child: shuffleFavoritesButton),
          ],
        );
      },
    );
  }
}

class _AsyncActionButton extends StatelessWidget {
  const _AsyncActionButton({
    required this.isCupertino,
    required this.icon,
    required this.label,
    this.loading = false,
    this.onPressed,
  });

  final bool isCupertino;
  final IconData icon;
  final String label;
  final bool loading;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonIcon = loading
        ? (isCupertino
              ? const CupertinoActivityIndicator(radius: 8)
              : const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
        : Icon(icon, size: 18);

    if (isCupertino) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        onPressed: onPressed == null
            ? null
            : () async {
                await onPressed!();
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buttonIcon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed == null
          ? null
          : () async {
              await onPressed!();
            },
      icon: buttonIcon,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isCupertino,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool isCupertino;
  final Future<void> Function() onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AdaptiveIconButton extends StatelessWidget {
  const _AdaptiveIconButton({
    required this.isCupertino,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final bool isCupertino;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
    );
  }
}

class _MetaLinkText extends StatelessWidget {
  const _MetaLinkText({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final mutedColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final style = TextStyle(
      fontSize: 12,
      color: onTap == null ? mutedColor : primaryColor,
      fontWeight: onTap == null ? FontWeight.normal : FontWeight.w600,
    );

    if (onTap == null) {
      return Text(text, style: style);
    }

    return GestureDetector(
      onTap: onTap,
      child: Text(text, style: style),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isCupertino,
    required this.onPlay,
    required this.onFavorite,
    required this.onQueue,
    required this.onDownload,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final Track track;
  final bool isCupertino;
  final VoidCallback onPlay;
  final Future<void> Function() onFavorite;
  final VoidCallback onQueue;
  final Future<void> Function() onDownload;
  final VoidCallback? onOpenAlbum;
  final VoidCallback? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compactActions = MediaQuery.sizeOf(context).width < 700;

    return _AdaptiveTile(
      isCupertino: isCupertino,
      title: track.name,
      subtitleWidget: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MetaLinkText(text: track.artistName ?? '-', onTap: onOpenArtist),
          const Text('•'),
          _MetaLinkText(text: track.albumName ?? '-', onTap: onOpenAlbum),
          const Text('•'),
          Text(_formatTrackDuration(track)),
        ],
      ),
      leading: _MediaArtwork(imageId: track.imageUrl ?? track.albumId),
      trailing: Wrap(
        spacing: 2,
        children: [
          _AdaptiveIconButton(
            isCupertino: isCupertino,
            tooltip: l10n.play,
            onPressed: onPlay,
            icon: isCupertino
                ? CupertinoIcons.play_fill
                : Icons.play_arrow_rounded,
          ),
          if (!compactActions)
            _AdaptiveIconButton(
              isCupertino: isCupertino,
              tooltip: l10n.addToQueue,
              onPressed: onQueue,
              icon: isCupertino
                  ? CupertinoIcons.text_badge_plus
                  : Icons.queue_music_rounded,
            ),
          _AdaptiveIconButton(
            isCupertino: isCupertino,
            tooltip: track.isFavorite
                ? l10n.removeFromFavorites
                : l10n.addToFavorites,
            onPressed: onFavorite,
            icon: track.isFavorite
                ? (isCupertino
                      ? CupertinoIcons.heart_fill
                      : Icons.favorite_rounded)
                : (isCupertino
                      ? CupertinoIcons.heart
                      : Icons.favorite_border_rounded),
          ),
          if (!compactActions)
            _AdaptiveIconButton(
              isCupertino: isCupertino,
              tooltip: l10n.download,
              onPressed: onDownload,
              icon: isCupertino
                  ? CupertinoIcons.arrow_down_circle
                  : Icons.download_rounded,
            ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.isCupertino,
    required this.onTap,
    required this.onPlay,
    required this.onFavorite,
  });

  final Album album;
  final bool isCupertino;
  final VoidCallback onTap;
  final Future<void> Function() onPlay;
  final Future<void> Function() onFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isCupertino
              ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _MediaArtwork(
                    imageId: album.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                album.artistName ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isCupertino
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 2,
                children: [
                  _AdaptiveIconButton(
                    isCupertino: isCupertino,
                    onPressed: onPlay,
                    icon: isCupertino
                        ? CupertinoIcons.play_fill
                        : Icons.play_arrow_rounded,
                  ),
                  _AdaptiveIconButton(
                    isCupertino: isCupertino,
                    onPressed: onFavorite,
                    icon: album.isFavorite
                        ? (isCupertino
                              ? CupertinoIcons.heart_fill
                              : Icons.favorite_rounded)
                        : (isCupertino
                              ? CupertinoIcons.heart
                              : Icons.favorite_border_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveTile extends StatelessWidget {
  const _AdaptiveTile({
    required this.isCupertino,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final bool isCupertino;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560 && trailing != null;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitleWidget ??
                Text(
                  subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCupertino
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(child: content),
                  if (!compact && trailing != null) trailing!,
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: trailing!,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCupertino
            ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

    if (onTap == null) {
      return tile;
    }

    return GestureDetector(onTap: onTap, child: tile);
  }
}

class _MediaArtwork extends StatelessWidget {
  const _MediaArtwork({this.imageId, this.size = 44, this.fit = BoxFit.cover});

  final String? imageId;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final raw = imageId;

    if (raw == null || raw.isEmpty) {
      return _fallbackArtwork();
    }

    final url = appState.getImageUrl(
      raw,
      width: size.round() * 2,
      height: size.round() * 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: fit,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        ),
      ),
    );
  }

  Widget _fallbackArtwork() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade400,
      child: const Icon(Icons.music_note_rounded),
    );
  }
}

class _SectionSearchField extends StatefulWidget {
  const _SectionSearchField({
    required this.isCupertino,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
  });

  final bool isCupertino;
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<_SectionSearchField> createState() => _SectionSearchFieldState();
}

class _SectionSearchFieldState extends State<_SectionSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SectionSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCupertino) {
      return CupertinoSearchTextField(
        controller: _controller,
        placeholder: widget.hintText,
        onChanged: widget.onChanged,
      );
    }

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isCupertino,
    required this.title,
    required this.subtitle,
  });

  final bool isCupertino;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCupertino
                  ? CupertinoIcons.music_note_2
                  : Icons.queue_music_rounded,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isCupertino
                    ? CupertinoColors.secondaryLabel.resolveFrom(context)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptivePanel extends StatelessWidget {
  const _AdaptivePanel({required this.isCupertino, required this.child});

  final bool isCupertino;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCupertino
            ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.isCupertino,
    required this.label,
    required this.control,
  });

  final bool isCupertino;
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: control),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isCupertino
                        ? CupertinoColors.label.resolveFrom(context)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: control),
            ],
          ),
        );
      },
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.isCupertino,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final bool isCupertino;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (isCupertino)
            CupertinoSwitch(value: value, onChanged: onChanged)
          else
            Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.isCupertino,
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final bool isCupertino;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? (isCupertino
              ? CupertinoColors.systemRed.resolveFrom(context)
              : Theme.of(context).colorScheme.error)
        : null;

    if (isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: color == null ? null : TextStyle(color: color),
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label, style: color == null ? null : TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

void _openAlbumFromTrack(
  BuildContext context,
  AppState appState,
  Track track,
  bool isCupertino,
) {
  Album? album;

  if (track.albumId != null) {
    for (final item in appState.albums) {
      if (item.id == track.albumId) {
        album = item;
        break;
      }
    }
  }

  if (album == null && track.albumName != null) {
    final target = track.albumName!.toLowerCase();
    for (final item in appState.albums) {
      if (item.name.toLowerCase() == target) {
        album = item;
        break;
      }
    }
  }

  if (album != null) {
    openAlbumDetailView(context, album: album, isCupertino: isCupertino);
  }
}

void _openArtistFromName(
  BuildContext context,
  AppState appState,
  String? artistName,
  bool isCupertino,
) {
  if (artistName == null || artistName.trim().isEmpty) {
    return;
  }

  final query = artistName.trim().toLowerCase();
  Artist? artist;

  for (final item in appState.artists) {
    final candidate = item.name.toLowerCase();
    if (candidate == query || candidate.contains(query)) {
      artist = item;
      break;
    }
  }

  if (artist != null) {
    openArtistDetailView(context, artist: artist, isCupertino: isCupertino);
  }
}

String _formatTrackDuration(Track track) {
  if (track.duration == null || track.duration! <= 0) {
    return '--:--';
  }

  final totalSeconds = track.duration! ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
