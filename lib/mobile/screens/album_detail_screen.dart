import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Reusable album detail screen - Apple Music style
class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Track>? _albumTracks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      // Get tracks that belong to this album
      final tracks = appState.tracks
          .where((t) => t.albumId == widget.album.id)
          .toList();
      // Sort by track number
      tracks.sort((a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0));
      
      if (mounted) {
        setState(() {
          _albumTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _albumTracks = [];
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
        final tracks = _albumTracks ?? [];

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                  slivers: [
                    // Gradient header with album art
                    SliverToBoxAdapter(
                      child: _buildGradientHeader(context, appState, tracks),
                    ),

                    // Track list
                    TrackList(
                      tracks: tracks,
                      currentTrackId: appState.audioHandler?.currentTrack?.id,
                      showTrackNumbers: false,
                      showArtwork: true,
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
    final artworkSize = 160.0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accentPink.withOpacity(0.7),
            AppTheme.accentPink.withOpacity(0.4),
            AppTheme.background(context),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Navigation bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.back, color: CupertinoColors.white, size: 26),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            
            // Album art on left, details on right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album artwork
                  Container(
                    width: artworkSize,
                    height: artworkSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedArtwork(
                        imageUrl: widget.album.imageUrl != null
                            ? appState.getImageUrl(widget.album.imageUrl!, width: 400, height: 400)
                            : null,
                        size: artworkSize,
                        borderRadius: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  
                  // Details on right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Album title
                        Text(
                          widget.album.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                            letterSpacing: -0.5,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // Artist name (pink, tappable)
                        GestureDetector(
                          onTap: () {
                            // Navigate to artist
                          },
                          child: Text(
                            widget.album.artistName ?? 'Unknown Artist',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.accentPink,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Album info (year, songs, duration)
                        Text(
                          _buildAlbumInfo(tracks),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: CupertinoColors.white.withOpacity(0.6),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        // Add button and more button row
                        Row(
                          children: [
                            // Add button (pink pill)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPink,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.add, size: 16, color: CupertinoColors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'ADD',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // More button (pink circle with ellipsis)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () => _showAlbumOptions(context, appState),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPink,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.ellipsis,
                                  size: 18,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.play_fill, size: 18, color: AppTheme.accentPink),
                            SizedBox(width: 8),
                            Text(
                              'Play',
                              style: TextStyle(
                                fontSize: 16,
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
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.shuffle, size: 18, color: AppTheme.accentPink),
                            SizedBox(width: 8),
                            Text(
                              'Shuffle',
                              style: TextStyle(
                                fontSize: 16,
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

  String _buildAlbumInfo(List<Track> tracks) {
    final parts = <String>[];
    if (widget.album.year != null) {
      parts.add('${widget.album.year}');
    }
    parts.add('${tracks.length} songs');
    parts.add(_formatDuration(tracks));
    return parts.join(' • ');
  }

  void _showAlbumOptions(BuildContext context, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to library
            },
            child: Text(
              widget.album.isFavorite ? 'Remove from Library' : 'Add to Library',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Download album
            },
            child: const Text('Download'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to playlist
            },
            child: const Text('Add to Playlist'),
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
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to playlist
            },
            child: const Text('Add to Playlist'),
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
