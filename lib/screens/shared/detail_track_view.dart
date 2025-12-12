import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../../widgets/apple_design/liquid_glass.dart';
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
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and info section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album/Playlist Art with glow
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        offset: const Offset(0, 8),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: appState.getImageUrl(
                              widget.imageUrl!,
                              width: 320,
                              height: 320,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 64,
                                color: CupertinoColors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 64,
                                color: CupertinoColors.white,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.viewType == DetailViewType.album
                                    ? [const Color(0xFF8B5CF6), const Color(0xFFEC4899)]
                                    : [const Color(0xFF06B6D4), const Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              widget.viewType == DetailViewType.album 
                                  ? CupertinoIcons.music_albums 
                                  : CupertinoIcons.music_note_list,
                              size: 64,
                              color: CupertinoColors.white,
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Artist name (for albums)
                      if (widget.artistName != null) ...[
                        Text(
                          widget.artistName!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
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
          
          // Action buttons with liquid glass
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Play button
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: tracks.isNotEmpty ? () => _playAllTracks() : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Shuffle button
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: tracks.isNotEmpty ? () {
                      _toggleShuffle();
                      _playAllTracks(shuffle: true);
                    } : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: _isShuffled
                                ? const LinearGradient(
                                    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.shuffle,
                                size: 18,
                                color: _isShuffled ? Colors.white : Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Shuffle',
                                style: TextStyle(
                                  color: _isShuffled ? Colors.white : Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
    return LiquidGradientBackground(
      child: CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          middle: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.name,
                  style: TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CupertinoActivityIndicator(color: CupertinoColors.white),
                          ),
                        ),
                      ),
                    )
                  else if (tracks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.music_note,
                                      size: 40,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No tracks found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This ${widget.viewType == DetailViewType.album ? 'album' : 'playlist'} appears to be empty',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}