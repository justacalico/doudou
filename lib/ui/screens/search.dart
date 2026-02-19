import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../../services/base_service.dart' show ServerType, SearchResults;
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/horizontal_card_scroll.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';
import '../widgets/section_header.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  SearchResults? _results;
  bool _loading = false;
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  void _onQueryChanged() {
    final q = _controller.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(_debounceDuration, () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final appState = context.read<AppState>();
    final results = await appState.searchMedia(query, limit: 50);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return PageTemplate(
            title: l10n.search,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        borderSide: Border.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Expanded(
                  child: _buildContent(context, appState, l10n),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState, AppLocalizations l10n) {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.spacingMd),
            Text(l10n.search, style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    if (_loading || _results == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final r = _results!;
    final isSoundCloud = appState.mediaServiceManager.currentServerType == ServerType.soundcloud ||
        appState.mediaServiceManager.currentServerType == ServerType.youtubeMusic;
    final showEmpty = (isSoundCloud || r.albums.isEmpty) && r.artists.isEmpty && r.tracks.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSoundCloud && r.albums.isNotEmpty) ...[
            SectionHeader(title: l10n.albums),
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: r.albums.length,
                itemBuilder: (context, i) {
                  final album = r.albums[i];
                  final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
                  return Padding(
                    padding: EdgeInsets.only(right: i < r.albums.length - 1 ? AppTheme.spacingMd : 0),
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
            const SizedBox(height: AppTheme.spacingLg),
          ],
          if (r.artists.isNotEmpty) ...[
            SectionHeader(title: l10n.artists),
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: r.artists.length,
                itemBuilder: (context, i) {
                  final artist = r.artists[i];
                  final imageUrl = artist.imageUrl != null ? appState.getImageUrl(artist.imageUrl!) : null;
                  return Padding(
                    padding: EdgeInsets.only(right: i < r.artists.length - 1 ? AppTheme.spacingMd : 0),
                    child: MusicCard(
                      title: artist.name,
                      subtitle: l10n.artist,
                      imageUrl: imageUrl,
                      size: 160,
                      placeholderIcon: Icons.person_rounded,
                      onTap: () => NavigationService().navigateToArtist(artist),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],
          if (r.tracks.isNotEmpty) ...[
            SectionHeader(title: l10n.songs),
            const SizedBox(height: AppTheme.spacingSm),
            ...r.tracks.take(50).toList().asMap().entries.map((e) {
              final i = e.key;
              final track = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: TrackTile(
                  track: track,
                  index: i,
                  playlist: r.tracks,
                  showTrackNumber: false,
                  showArtwork: true,
                ),
              );
            }),
          ],
          if (showEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Text(
                  l10n.noSongsFound,
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ),
            ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
