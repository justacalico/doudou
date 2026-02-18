import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/ui/desktop/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';
import 'package:doudou/ui/templates/track_list.dart';

/// Search page built from PageTemplate, MusicCard, and TrackListTemplate.
/// Uses server-side search (e.g. SoundCloud) when the user types a query.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = ValueNotifier<String>('');
  final _controller = TextEditingController();

  SearchResults? _searchResults;
  bool _searchLoading = false;
  Timer? _debounce;

  static const Duration _searchDebounce = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) appState.loadLibraryData();
    });
  }

  void _onQueryChanged() {
    _query.value = _controller.text;
    final q = _controller.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _searchResults = null;
        _searchLoading = false;
      });
      return;
    }
    _debounce = Timer(_searchDebounce, () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _searchLoading = true;
    });
    final appState = context.read<AppState>();
    final results = await appState.searchMedia(query, limit: 50);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searchLoading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
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
            SizedBox(
              width: 280,
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
              if (_searchLoading || _searchResults == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
              final albums = _searchResults!.albums;
              final artists = _searchResults!.artists;
              final tracks = _searchResults!.tracks;
              final isSoundCloud = appState.mediaServiceManager
                      .currentServerType ==
                  ServerType.soundcloud;
              final showEmpty = (isSoundCloud || albums.isEmpty) &&
                  artists.isEmpty &&
                  tracks.isEmpty;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSoundCloud && albums.isNotEmpty) ...[
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
                    if (showEmpty)
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
