import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Playlist detail screen - Apple Music style
class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Track>? _playlistTracks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final tracks = await appState.mediaServiceManager.getPlaylistTracks(widget.playlist.id);
      if (mounted) {
        setState(() {
          _playlistTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _playlistTracks = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(List<Track> tracks) {
    final totalMs = tracks.fold<int>(0, (sum, t) => sum + (t.duration ?? 0));
    final duration = Duration(milliseconds: totalMs);
    if (duration.inHours > 0) {
      return '${duration.inHours} hr ${duration.inMinutes % 60} min';
    }
    return '${duration.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tracks = _playlistTracks ?? [];

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                  slivers: [
                    // Gradient header
                    SliverToBoxAdapter(
                      child: _buildGradientHeader(context, appState, tracks),
                    ),

                    // Track list
                    TrackList(
                      tracks: tracks,
                      currentTrackId: appState.audioHandler?.currentTrack?.id,
                      getImageUrl: appState.getImageUrl,
                      onTrackTap: (track, index) {
                        appState.audioHandler?.playPlaylist(tracks, index);
                      },
                      onMoreTap: (track) => _showTrackOptions(context, appState, track, tracks),
                    ),

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

  Widget _buildGradientHeader(BuildContext context, AppState appState, List<Track> tracks) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artworkSize = screenWidth * 0.55;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accentPink.withOpacity(0.8),
            AppTheme.accentPink.withOpacity(0.4),
            AppTheme.background(context),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Navigation bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.back, color: CupertinoColors.white, size: 28),
                  ),
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {},
                        child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 24),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showPlaylistOptions(context),
                        child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white, size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            // Artwork with shadow
            Container(
              width: artworkSize,
              height: artworkSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: CachedArtwork(
                imageUrl: widget.playlist.imageUrl != null
                    ? appState.getImageUrl(widget.playlist.imageUrl!, width: 500, height: 500)
                    : null,
                size: artworkSize,
                borderRadius: AppTheme.radiusM,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            
            // Playlist title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Text(
                widget.playlist.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            
            // Playlist info
            Text(
              '${tracks.length} songs • ${_formatDuration(tracks)}',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: CupertinoColors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            
            // Play and Shuffle buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: tracks.isNotEmpty
                          ? () => appState.audioHandler?.playPlaylist(tracks, 0)
                          : null,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.play_fill, size: 22, color: AppTheme.accentPink),
                            SizedBox(width: 8),
                            Text(
                              'Play',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: tracks.isNotEmpty
                          ? () {
                              final shuffled = List<Track>.from(tracks)..shuffle();
                              appState.audioHandler?.playPlaylist(shuffled, 0);
                            }
                          : null,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.shuffle, size: 22, color: AppTheme.accentPink),
                            SizedBox(width: 8),
                            Text(
                              'Shuffle',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit Playlist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Download'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Delete Playlist'),
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

  void _showTrackOptions(BuildContext context, AppState appState, Track track, List<Track> allTracks) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(track.name),
        message: Text(track.artistName ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: Text(
              track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.audioHandler?.addToQueue(track);
            },
            child: const Text('Play Next'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // TODO: Remove from playlist
            },
            child: const Text('Remove from Playlist'),
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
