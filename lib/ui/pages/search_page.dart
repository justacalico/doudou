import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
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
              final query = q.trim().toLowerCase();
              if (query.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 64, color: DesktopTheme.textMuted),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.search,
                        style: TextStyle(
                            fontSize: 16, color: DesktopTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              final albums = appState.albums
                  .where((a) =>
                      a.name.toLowerCase().contains(query) ||
                      (a.artistName?.toLowerCase().contains(query) ?? false))
                  .take(6)
                  .toList();
              final artists = appState.artists
                  .where((a) => a.name.toLowerCase().contains(query))
                  .take(6)
                  .toList();
              final tracks = appState.tracks
                  .where((t) =>
                      t.name.toLowerCase().contains(query) ||
                      (t.artistName?.toLowerCase().contains(query) ?? false) ||
                      (t.albumName?.toLowerCase().contains(query) ?? false))
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
                                      : 0),
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
                                      : 0),
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
                                color: DesktopTheme.textSecondary),
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
}
