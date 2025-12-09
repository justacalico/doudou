import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../partials/tracks/track_list_item.dart';
import '../partials/player/mini_player.dart';

enum DetailViewType { album, playlist }

class DetailTrackView extends StatefulWidget {
  final String id;
  final String name;
  final String? imageUrl;
  final String? artistName;
  final DetailViewType viewType;
  final int? trackCount;
  final String? year;

  const DetailTrackView({
    super.key,
    required this.id,
    required this.name,
    required this.viewType,
    this.imageUrl,
    this.artistName,
    this.trackCount,
    this.year,
  });

  // Constructor for Album
  factory DetailTrackView.album(Album album) {
    return DetailTrackView(
      id: album.id,
      name: album.name,
      viewType: DetailViewType.album,
      imageUrl: album.imageUrl,
      artistName: album.artistName,
      year: album.year?.toString(),
    );
  }

  // Constructor for Playlist
  factory DetailTrackView.playlist(Playlist playlist) {
    return DetailTrackView(
      id: playlist.id,
      name: playlist.name,
      viewType: DetailViewType.playlist,
      imageUrl: playlist.imageUrl,
      trackCount: playlist.trackCount,
    );
  }

  @override
  State<DetailTrackView> createState() => _DetailTrackViewState();
}

class _DetailTrackViewState extends State<DetailTrackView> {
  List<Track> tracks = [];
  bool isLoading = true;
  bool _isShuffled = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();

    // Ensure tracks are loaded first for albums
    if (widget.viewType == DetailViewType.album && appState.tracks.isEmpty && !appState.isLoading) {
      await appState.loadLibraryData();
    }

    try {
      List<Track> loadedTracks = [];
      
      if (widget.viewType == DetailViewType.album) {
        // First try to get tracks from the API
        final albumTracks = await appState.getAlbumTracks(widget.id);
        
        if (albumTracks.isNotEmpty) {
          loadedTracks = albumTracks;
        } else {
          // If no tracks from API, try filtering from existing tracks
          final allTracks = appState.tracks;
          if (allTracks.isNotEmpty) {
            loadedTracks = allTracks.where((track) => track.albumId == widget.id).toList();
            
            // Sort by track number if available
            loadedTracks.sort((a, b) {
              if (a.trackNumber != null && b.trackNumber != null) {
                return a.trackNumber!.compareTo(b.trackNumber!);
              }
              return a.name.compareTo(b.name);
            });
          }
        }
      } else if (widget.viewType == DetailViewType.playlist) {
        if (kDebugMode) {
          print('Loading tracks for playlist: ${widget.id}');
        }
        
        loadedTracks = await appState.getPlaylistTracks(widget.id);
        
        if (kDebugMode) {
          print('Loaded ${loadedTracks.length} tracks for playlist: ${widget.name}');
        }
      }

      setState(() {
        tracks = loadedTracks;
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading ${widget.viewType.name} tracks: $e');
      }
      
      setState(() {
        tracks = [];
        isLoading = false;
      });
    }
  }

  Future<void> _refreshTracks() async {
    setState(() {
      isLoading = true;
    });
    await _loadTracks();
  }

  void _playAllTracks({bool shuffle = false}) {
    if (tracks.isEmpty) return;

    final appState = context.read<AppState>();
    List<Track> tracksToPlay = List.from(tracks);
    
    if (shuffle) {
      tracksToPlay.shuffle();
    }
    
    appState.playPlaylist(tracksToPlay, 0);
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
    });
  }

  Widget _buildHeader() {
    final appState = context.read<AppState>();
    
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and info section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album/Playlist Art
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: appState.getImageUrl(
                              widget.imageUrl!,
                              width: 320,
                              height: 320,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF1C1C1C),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 64,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF1C1C1C),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 64,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1C1C1C),
                            child: Icon(
                              widget.viewType == DetailViewType.album 
                                  ? CupertinoIcons.music_albums 
                                  : CupertinoIcons.music_note_list,
                              size: 64,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Artist name (for albums)
                      if (widget.artistName != null) ...[
                        Text(
                          widget.artistName!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      // Metadata
                      if (widget.year != null || widget.trackCount != null) ...[
                        Text(
                          [
                            if (widget.year != null) widget.year!,
                            if (widget.trackCount != null) '${widget.trackCount} tracks',
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      

                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Play button
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: tracks.isNotEmpty ? () => _playAllTracks() : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.play_fill, size: 18),
                        SizedBox(width: 8),
                        Text('Play'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Shuffle button
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: _isShuffled ? CupertinoColors.activeBlue : const Color(0xFF1C1C1C),
                    onPressed: tracks.isNotEmpty ? () {
                      _toggleShuffle();
                      _playAllTracks(shuffle: true);
                    } : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.shuffle,
                          size: 18,
                          color: _isShuffled ? CupertinoColors.white : CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            color: _isShuffled ? CupertinoColors.white : CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF000000).withOpacity(0.9),
        middle: Text(
          widget.name,
          style: const TextStyle(color: CupertinoColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: widget.viewType == DetailViewType.album ? 'Albums' : 'Playlists',
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            CustomScrollView(
            slivers: [
              // Pull to refresh
              CupertinoSliverRefreshControl(
                onRefresh: _refreshTracks,
              ),
              
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              
              // Track list
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CupertinoActivityIndicator(color: CupertinoColors.white),
                    ),
                  ),
                )
              else if (tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.music_note,
                            size: 64,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tracks found',
                            style: const TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = tracks[index];
                      return TrackListItem(
                        track: track,
                        showAlbumArt: widget.viewType == DetailViewType.playlist,
                        showTrackNumber: widget.viewType == DetailViewType.album,
                        onTap: () {
                          final appState = context.read<AppState>();
                          appState.playPlaylist(tracks, index);
                        },
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              
              // Bottom padding for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          
            // Mini player at bottom
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
      ),
    );
  }
}