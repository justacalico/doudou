import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_detail_screen.dart';

/// Artist detail screen - Apple Music style
class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<Album>? _artistAlbums;
  List<Track>? _artistTracks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      // Get albums by this artist
      final albums = appState.albums
          .where((a) => a.artistName == widget.artist.name)
          .toList();

      // Get tracks by this artist
      final tracks = appState.tracks
          .where((t) => t.artistName == widget.artist.name)
          .toList();

      if (mounted) {
        setState(() {
          _artistAlbums = albums;
          _artistTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _artistAlbums = [];
          _artistTracks = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = _artistAlbums ?? [];
        final tracks = _artistTracks ?? [];
        final screenWidth = MediaQuery.of(context).size.width;
        final artworkSize = screenWidth * 0.5;

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                  slivers: [
                    // Artist header
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          // Background gradient
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.accentPink.withOpacity(0.3),
                                  AppTheme.background(context),
                                ],
                              ),
                            ),
                          ),
                          
                          SafeArea(
                            child: Column(
                              children: [
                                // Navigation
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        child: const Icon(
                                          CupertinoIcons.back,
                                          color: CupertinoColors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        child: const Icon(
                                          CupertinoIcons.ellipsis,
                                          color: CupertinoColors.white,
                                        ),
                                        onPressed: () => _showArtistOptions(context),
                                      ),
                                    ],
                                  ),
                                ),

                                // Artist image
                                ClipOval(
                                  child: Container(
                                    width: artworkSize,
                                    height: artworkSize,
                                    color: AppTheme.elevated(context),
                                    child: widget.artist.imageUrl != null
                                        ? CachedArtwork(
                                            imageUrl: appState.getImageUrl(
                                              widget.artist.imageUrl!,
                                              width: 400,
                                              height: 400,
                                            ),
                                            size: artworkSize,
                                            borderRadius: artworkSize / 2,
                                            placeholderIcon: CupertinoIcons.person_fill,
                                          )
                                        : Icon(
                                            CupertinoIcons.person_fill,
                                            size: artworkSize * 0.4,
                                            color: AppTheme.textSecondary(context),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingL),

                                // Artist name
                                Text(
                                  widget.artist.name,
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeLargeTitle,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: AppTheme.spacingS),

                                // Stats
                                Text(
                                  '${albums.length} albums • ${tracks.length} songs',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeFootnote,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingL),

                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ActionButton(
                                      icon: CupertinoIcons.play_fill,
                                      label: 'Play',
                                      isPrimary: true,
                                      onTap: () {
                                        if (tracks.isNotEmpty) {
                                          appState.audioHandler?.playPlaylist(tracks, 0);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    _ActionButton(
                                      icon: CupertinoIcons.shuffle,
                                      label: 'Shuffle',
                                      onTap: () {
                                        if (tracks.isNotEmpty) {
                                          final shuffled = List<Track>.from(tracks)..shuffle();
                                          appState.audioHandler?.playPlaylist(shuffled, 0);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Albums section
                    if (albums.isNotEmpty) ...[
                      const SliverSectionHeader(title: 'Albums'),
                      SliverToBoxAdapter(
                        child: AlbumRow(
                          albums: albums,
                          getImageUrl: appState.getImageUrl,
                          onAlbumTap: (album) => _navigateToAlbum(context, album),
                        ),
                      ),
                    ],

                    // Top Songs section
                    if (tracks.isNotEmpty) ...[
                      const SliverSectionHeader(title: 'Songs'),
                      TrackList(
                        tracks: tracks.take(10).toList(),
                        currentTrackId: appState.audioHandler?.currentTrack?.id,
                        getImageUrl: appState.getImageUrl,
                        onTrackTap: (track, index) {
                          appState.audioHandler?.playPlaylist(tracks, index);
                        },
                      ),
                    ],

                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 150),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _navigateToAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AlbumDetailScreen(album: album),
      ),
    );
  }

  void _showArtistOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Follow Artist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXL,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.accentPink : AppTheme.accentPink.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? CupertinoColors.white : AppTheme.accentPink,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: isPrimary ? CupertinoColors.white : AppTheme.accentPink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
