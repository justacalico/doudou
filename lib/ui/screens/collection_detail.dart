import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../../utils/display_utils.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/artwork_hero.dart';
import '../widgets/music_card.dart';
import '../widgets/track_tile.dart';
import '../widgets/universal_image.dart';

/// Single template for album, playlist, and artist detail. Header + track list (artist: tabs for albums / songs).
class CollectionDetailScreen extends StatefulWidget {
  final DetailPageType type;
  final dynamic data;

  const CollectionDetailScreen({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<Track> _tracks = [];
  List<Album> _artistAlbums = [];
  bool _loading = true;
  String _artistTab = 'albums';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      switch (widget.type) {
        case DetailPageType.album:
          final album = widget.data as Album;
          _tracks = await appState.getAlbumTracks(album.id);
          _tracks.sort((a, b) => (a.trackNumber ?? 999).compareTo(b.trackNumber ?? 999));
          break;
        case DetailPageType.playlist:
          final playlist = widget.data as Playlist;
          _tracks = await appState.getPlaylistTracks(playlist.id);
          break;
        case DetailPageType.artist:
          final artist = widget.data as Artist;
          final allTracks = await appState.getArtistTracks(artist);
          _tracks = allTracks;
          _artistAlbums = albumsFromTracks(allTracks, artistName: artist.name, artistId: artist.id);
          _artistAlbums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (_artistAlbums.isEmpty) _artistTab = 'songs';
          break;
      }
    } catch (_) {
      _tracks = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nav = NavigationService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => nav.goBack(),
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    _title(l10n),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, theme, l10n),
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildActionButtons(context, l10n),
                    const SizedBox(height: AppTheme.spacingLg),
                    if (widget.type == DetailPageType.artist && _artistAlbums.isNotEmpty) ...[
                      _buildArtistTabs(context, theme),
                      const SizedBox(height: AppTheme.spacingMd),
                      if (_artistTab == 'albums') _buildArtistAlbumsGrid(context) else _buildTrackList(context),
                    ] else
                      _buildTrackList(context),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    switch (widget.type) {
      case DetailPageType.album:
        return (widget.data as Album).name;
      case DetailPageType.playlist:
        return (widget.data as Playlist).name;
      case DetailPageType.artist:
        return (widget.data as Artist).name;
    }
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    switch (widget.type) {
      case DetailPageType.album:
        final album = widget.data as Album;
        final imageUrl = album.imageUrl != null ? context.read<AppState>().getImageUrl(album.imageUrl!) : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: ArtworkHero(
            imageUrl: imageUrl,
            width: 240,
            height: 240,
          ),
        );
      case DetailPageType.playlist:
        final playlist = widget.data as Playlist;
        final imageUrl = playlist.imageUrl != null ? context.read<AppState>().getImageUrl(playlist.imageUrl!) : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: ArtworkHero(
            imageUrl: imageUrl,
            width: 240,
            height: 240,
          ),
        );
      case DetailPageType.artist:
        final artist = widget.data as Artist;
        final imageUrl = artist.imageUrl != null ? context.read<AppState>().getImageUrl(artist.imageUrl!) : null;
        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? UniversalImage(imageUrl: imageUrl, width: 200, height: 200)
                  : Icon(Icons.person_rounded, size: 80, color: AppTheme.textMuted),
            ),
          ),
        );
    }
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    final appState = context.read<AppState>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _tracks.isEmpty
              ? null
              : () async {
                  await appState.playPlaylist(_tracks, 0);
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(widget.type == DetailPageType.playlist ? l10n.playAll : l10n.play),
        ),
        OutlinedButton.icon(
          onPressed: _tracks.isEmpty
              ? null
              : () async {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  await appState.playPlaylist(shuffled, 0);
                },
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(l10n.shuffle),
        ),
      ],
    );
  }

  Widget _buildArtistTabs(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _TabChip(
          label: l10n.albums,
          selected: _artistTab == 'albums',
          onTap: () => setState(() => _artistTab = 'albums'),
        ),
        const SizedBox(width: 8),
        _TabChip(
          label: l10n.popularSongs,
          selected: _artistTab == 'songs',
          onTap: () => setState(() => _artistTab = 'songs'),
        ),
      ],
    );
  }

  Widget _buildArtistAlbumsGrid(BuildContext context) {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final nav = NavigationService();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : (constraints.maxWidth > 400 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: AppTheme.spacingMd,
            mainAxisSpacing: AppTheme.spacingMd,
          ),
          itemCount: _artistAlbums.length,
          itemBuilder: (context, i) {
            final album = _artistAlbums[i];
            final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
            return MusicCard(
              title: album.name,
              subtitle: album.artistName ?? l10n.unknownArtist,
              imageUrl: imageUrl,
              size: 160,
              onTap: () => nav.navigateToAlbum(album),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackList(BuildContext context) {
    if (_tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Text(
            AppLocalizations.of(context).noSongsFound,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 16),
          ),
        ),
      );
    }
    return Column(
      children: List.generate(
        _tracks.length,
        (i) => TrackTile(
          track: _tracks[i],
          index: i,
          playlist: _tracks,
          showTrackNumber: true,
          showArtwork: true,
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? theme.colorScheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
