import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';
import 'package:doudou/ui/templates/track_list.dart';

/// Search page built from PageTemplate, MusicCard, and TrackListTemplate.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = ValueNotifier<String>('');
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => _query.value = _controller.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) appState.loadLibraryData();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: l10n.search,
          actions: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  isDense: true,
                  filled: true,
                  fillColor: DesktopTheme.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
          child: ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, q, _) {
              final query = q.trim();
              if (query.isEmpty) {
                return _recommendationsView(context, appState, l10n);
              }
              // YouTube Music: remote search (community playlists + songs)
              if (appState.mediaServiceManager.currentServerType ==
                  ServerType.youtubeMusic) {
                return FutureBuilder(
                  future: appState.mediaServiceManager.search(query, limit: 25),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(DesktopTheme.spacingXl),
                          child:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const CircularProgressIndicator()
                              : Text(
                                  l10n.noSongsFound,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: DesktopTheme.textSecondary,
                                  ),
                                ),
                        ),
                      );
                    }
                    final results = snapshot.data!;
                    final playlists = results.playlists;
                    final tracks = results.tracks;
                    final artists = results.artists;
                    if (playlists.isEmpty &&
                        tracks.isEmpty &&
                        artists.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(DesktopTheme.spacingXl),
                          child: Text(
                            l10n.noSongsFound,
                            style: TextStyle(
                              fontSize: 16,
                              color: DesktopTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (artists.isNotEmpty) ...[
                            SectionHeader(title: l10n.artists),
                            const SizedBox(height: DesktopTheme.spacingSm),
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: artists.length,
                                itemBuilder: (context, i) {
                                  final artist = artists[i];
                                  final imageUrl = artist.imageUrl;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: i < artists.length - 1
                                          ? DesktopTheme.spacingMd
                                          : 0,
                                    ),
                                    child: MusicCard(
                                      title: artist.name,
                                      subtitle: l10n.artist,
                                      imageUrl: imageUrl,
                                      size: 160,
                                      onTap: () => NavigationService()
                                          .navigateToArtist(artist),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: DesktopTheme.spacingLg),
                          ],
                          if (playlists.isNotEmpty) ...[
                            SectionHeader(title: l10n.communityPlaylists),
                            const SizedBox(height: DesktopTheme.spacingSm),
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: playlists.length,
                                itemBuilder: (context, i) {
                                  final playlist = playlists[i];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: i < playlists.length - 1
                                          ? DesktopTheme.spacingMd
                                          : 0,
                                    ),
                                    child: MusicCard(
                                      title: playlist.name,
                                      subtitle: l10n.playlists,
                                      imageUrl: playlist.imageUrl,
                                      size: 160,
                                      onTap: () => NavigationService()
                                          .navigateToPlaylist(playlist),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: DesktopTheme.spacingLg),
                          ],
                          if (tracks.isNotEmpty) ...[
                            SectionHeader(title: l10n.songs),
                            const SizedBox(height: DesktopTheme.spacingSm),
                            SizedBox(
                              height: 320,
                              child: TrackListTemplate(
                                tracks: tracks,
                                showTrackNumber: false,
                                showArtist: true,
                                showAlbum: true,
                                showArtwork: true,
                              ),
                            ),
                          ],
                          const SizedBox(height: 120),
                        ],
                      ),
                    );
                  },
                );
              }
              final queryLower = query.toLowerCase();
              final albums = appState.albums
                  .where(
                    (a) =>
                        a.name.toLowerCase().contains(queryLower) ||
                        (a.artistName?.toLowerCase().contains(queryLower) ??
                            false),
                  )
                  .take(6)
                  .toList();
              final artists = appState.artists
                  .where((a) => a.name.toLowerCase().contains(queryLower))
                  .take(6)
                  .toList();
              final tracks = appState.tracks
                  .where(
                    (t) =>
                        t.name.toLowerCase().contains(queryLower) ||
                        (t.artistName?.toLowerCase().contains(queryLower) ??
                            false) ||
                        (t.albumName?.toLowerCase().contains(queryLower) ??
                            false),
                  )
                  .toList();

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (albums.isNotEmpty) ...[
                      SectionHeader(title: l10n.albums),
                      const SizedBox(height: DesktopTheme.spacingSm),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: albums.length,
                          itemBuilder: (context, i) {
                            final album = albums[i];
                            final imageUrl = album.imageUrl != null
                                ? appState.getImageUrl(album.imageUrl!)
                                : null;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: i < albums.length - 1
                                    ? DesktopTheme.spacingMd
                                    : 0,
                              ),
                              child: MusicCard(
                                title: album.name,
                                subtitle:
                                    album.artistName ?? l10n.unknownArtist,
                                imageUrl: imageUrl,
                                size: 160,
                                onTap: () =>
                                    NavigationService().navigateToAlbum(album),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: DesktopTheme.spacingLg),
                    ],
                    if (artists.isNotEmpty) ...[
                      SectionHeader(title: l10n.artists),
                      const SizedBox(height: DesktopTheme.spacingSm),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: artists.length,
                          itemBuilder: (context, i) {
                            final artist = artists[i];
                            final imageUrl = artist.imageUrl != null
                                ? appState.getImageUrl(artist.imageUrl!)
                                : null;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: i < artists.length - 1
                                    ? DesktopTheme.spacingMd
                                    : 0,
                              ),
                              child: MusicCard(
                                title: artist.name,
                                subtitle: l10n.artist,
                                imageUrl: imageUrl,
                                size: 160,
                                onTap: () => NavigationService()
                                    .navigateToArtist(artist),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: DesktopTheme.spacingLg),
                    ],
                    if (tracks.isNotEmpty) ...[
                      SectionHeader(title: l10n.songs),
                      const SizedBox(height: DesktopTheme.spacingSm),
                      SizedBox(
                        height: 320,
                        child: TrackListTemplate(
                          tracks: tracks,
                          showTrackNumber: false,
                          showArtist: true,
                          showAlbum: true,
                          showArtwork: true,
                        ),
                      ),
                    ],
                    if (query.isNotEmpty &&
                        albums.isEmpty &&
                        artists.isEmpty &&
                        tracks.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(DesktopTheme.spacingXl),
                          child: Text(
                            l10n.noSongsFound,
                            style: TextStyle(
                              fontSize: 16,
                              color: DesktopTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 120),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _recommendationsView(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final recent = appState.recentTracks.take(8).toList();
    final favorites = appState.favoriteTracks.take(8).toList();
    final mostPlayed =
        appState.tracks.where((t) => (t.playCount ?? 0) > 0).toList()
          ..sort((a, b) => (b.playCount ?? 0).compareTo(a.playCount ?? 0));
    final topPlayed = mostPlayed.take(8).toList();
    final playlistPicks = _pickVaried<Playlist>(
      appState.playlists,
      10,
      salt: 'search-playlists',
      keyOf: (p) => p.id,
    );
    final albumPicks = _pickVaried<Album>(
      appState.albums,
      10,
      salt: 'search-albums',
      keyOf: (a) => a.id,
    );
    final artistPicks = _pickVaried<Artist>(
      appState.artists,
      10,
      salt: 'search-artists',
      keyOf: (a) => a.id,
    );

    if (recent.isEmpty &&
        favorites.isEmpty &&
        topPlayed.isEmpty &&
        playlistPicks.isEmpty &&
        albumPicks.isEmpty &&
        artistPicks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: DesktopTheme.textMuted),
            const SizedBox(height: DesktopTheme.spacingMd),
            Text(
              l10n.searchStartTyping,
              style: TextStyle(fontSize: 16, color: DesktopTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            SectionHeader(
              title: l10n.homeContinueListening,
              subtitle: l10n.searchRecentlyPlayedSubtitle,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 320,
              child: TrackListTemplate(
                tracks: recent,
                showTrackNumber: false,
                showArtist: true,
                showAlbum: true,
                showArtwork: true,
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingLg),
          ],
          if (favorites.isNotEmpty) ...[
            SectionHeader(
              title: l10n.searchFavoriteTracks,
              subtitle: l10n.searchFavoriteTracksSubtitle,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 320,
              child: TrackListTemplate(
                tracks: favorites,
                showTrackNumber: false,
                showArtist: true,
                showAlbum: true,
                showArtwork: true,
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingLg),
          ],
          if (topPlayed.isNotEmpty) ...[
            SectionHeader(
              title: l10n.searchMostPlayed,
              subtitle: l10n.searchMostPlayedSubtitle,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 320,
              child: TrackListTemplate(
                tracks: topPlayed,
                showTrackNumber: false,
                showArtist: true,
                showAlbum: true,
                showArtwork: true,
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingLg),
          ],
          if (playlistPicks.isNotEmpty) ...[
            SectionHeader(
              title: l10n.playlists,
              subtitle: l10n.searchSuggestedPlaylists,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlistPicks.length,
                itemBuilder: (context, i) {
                  final playlist = playlistPicks[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < playlistPicks.length - 1
                          ? DesktopTheme.spacingMd
                          : 0,
                    ),
                    child: MusicCard(
                      title: playlist.name,
                      subtitle: l10n.countSongs(playlist.trackCount),
                      imageUrl: playlist.imageUrl,
                      size: 160,
                      onTap: () =>
                          NavigationService().navigateToPlaylist(playlist),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingLg),
          ],
          if (albumPicks.isNotEmpty) ...[
            SectionHeader(
              title: l10n.albums,
              subtitle: l10n.searchAlbumsToExplore,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: albumPicks.length,
                itemBuilder: (context, i) {
                  final album = albumPicks[i];
                  final imageUrl = album.imageUrl != null
                      ? appState.getImageUrl(album.imageUrl!)
                      : null;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < albumPicks.length - 1
                          ? DesktopTheme.spacingMd
                          : 0,
                    ),
                    child: MusicCard(
                      title: album.name,
                      subtitle: album.artistName ?? l10n.unknownArtist,
                      imageUrl: imageUrl,
                      size: 160,
                      onTap: () => NavigationService().navigateToAlbum(album),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingLg),
          ],
          if (artistPicks.isNotEmpty) ...[
            SectionHeader(
              title: l10n.artists,
              subtitle: l10n.searchArtistsToExplore,
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: artistPicks.length,
                itemBuilder: (context, i) {
                  final artist = artistPicks[i];
                  final imageUrl = artist.imageUrl != null
                      ? appState.getImageUrl(artist.imageUrl!)
                      : null;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < artistPicks.length - 1
                          ? DesktopTheme.spacingMd
                          : 0,
                    ),
                    child: MusicCard(
                      title: artist.name,
                      subtitle: l10n.artist,
                      imageUrl: imageUrl,
                      size: 160,
                      onTap: () => NavigationService().navigateToArtist(artist),
                    ),
                  );
                },
              ),
            ),
          ],
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
}
