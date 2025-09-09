import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/jellyfin_models.dart';
import '../../../providers/app_state.dart';
import '../../partials/tracks/track_list_item.dart';
import '../../partials/player/mini_player.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Track> tracks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    
    // Ensure tracks are loaded first
    if (appState.tracks.isEmpty && !appState.isLoading) {
      await appState.loadLibraryData();
    }
    
    try {
      // First try to get tracks from the API
      final albumTracks = await appState.getAlbumTracks(widget.album.id);
      
      if (albumTracks.isNotEmpty) {
        setState(() {
          tracks = albumTracks;
          isLoading = false;
        });
        return;
      }
      
      // If no tracks from API, try filtering from existing tracks
      final allTracks = appState.tracks;
      final filteredTracks = allTracks.where((track) => 
        track.albumId == widget.album.id || 
        track.albumName?.toLowerCase() == widget.album.name.toLowerCase()
      ).toList();
      
      // Sort by track number if available
      filteredTracks.sort((a, b) {
        final aTrackNum = a.trackNumber ?? 0;
        final bTrackNum = b.trackNumber ?? 0;
        return aTrackNum.compareTo(bTrackNum);
      });
      
      setState(() {
        tracks = filteredTracks;
        isLoading = false;
      });
    } catch (e) {
      // Fallback to filtering existing tracks if API call fails
      final allTracks = appState.tracks;
      final filteredTracks = allTracks.where((track) => 
        track.albumId == widget.album.id || 
        track.albumName?.toLowerCase() == widget.album.name.toLowerCase()
      ).toList();
      
      // Sort by track number if available
      filteredTracks.sort((a, b) {
        final aTrackNum = a.trackNumber ?? 0;
        final bTrackNum = b.trackNumber ?? 0;
        return aTrackNum.compareTo(bTrackNum);
      });
      
      setState(() {
        tracks = filteredTracks;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Custom app bar with gradient overlay
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                backgroundColor: const Color(0xFF000000),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Album artwork background
                      widget.album.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: appState.jellyfinService.getImageUrl(
                                widget.album.imageUrl!,
                                width: 800,
                                height: 800,
                              ),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF1C1C1E),
                                child: const Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF1C1C1E),
                                child: const Center(
                                  child: Icon(
                                    CupertinoIcons.music_albums_fill,
                                    size: 80,
                                    color: Color(0xFF48484A),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1C1C1E),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.music_albums_fill,
                                  size: 80,
                                  color: Color(0xFF48484A),
                                ),
                              ),
                            ),
                      // Gradient overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x00000000),
                              Color(0x99000000),
                              Color(0xFF000000),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x80000000),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                ),
                actions: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showMoreOptions(context, appState),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        CupertinoIcons.ellipsis,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              // Album info section with improved design
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF000000),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Album title
                      Text(
                        widget.album.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Artist name with styling
                      if (widget.album.artistName != null)
                        GestureDetector(
                          onTap: () {
                            // TODO: Navigate to artist page
                          },
                          child: Text(
                            widget.album.artistName!,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFFFF453A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Album stats row
                      if (tracks.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.music_note,
                                    size: 14,
                                    color: Color(0xFF8E8E93),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.time,
                                    size: 14,
                                    color: Color(0xFF8E8E93),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTotalDuration(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Enhanced action buttons
                      Row(
                        children: [
                          // Play button - now larger and more prominent
                          Expanded(
                            flex: 3,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: const Color(0xFFFF453A),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => _playAllTracks(),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.play_fill,
                                    color: CupertinoColors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Play',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Shuffle button
                          Expanded(
                            flex: 2,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => _shuffleAllTracks(),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.shuffle,
                                    color: CupertinoColors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Shuffle',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Download button (if not all downloaded)
                          Consumer<AppState>(
                            builder: (context, appState, child) {
                              final bool allTracksDownloaded = tracks.isNotEmpty && 
                                  tracks.every((track) => appState.downloadService.isTrackDownloaded(track.id));
                              
                              if (allTracksDownloaded) {
                                return const SizedBox.shrink();
                              }
                              
                              return CupertinoButton(
                                padding: const EdgeInsets.all(16),
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () => _downloadAlbum(),
                                child: const Icon(
                                  CupertinoIcons.cloud_download,
                                  color: CupertinoColors.white,
                                  size: 18,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (tracks.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.music_note,
                          size: 64,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tracks found',
                          style: TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final track = tracks[index];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 1),
                        child: TrackListItem(
                          track: track,
                          trackNumber: index + 1,
                          onTap: () => _playTrack(track, index),
                          showAlbumArt: false,
                          showTrackNumber: true,
                          showDuration: true,
                          showDownloadButton: true,
                          showFavoriteButton: true,
                        ),
                      );
                    }, childCount: tracks.length),
                  ),
                ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          widget.album.name,
          style: const TextStyle(fontSize: 16),
        ),
        message: widget.album.artistName != null
            ? Text(
                widget.album.artistName!,
                style: const TextStyle(fontSize: 14),
              )
            : null,
        actions: [
          // Download Album
          Consumer<AppState>(
            builder: (context, appState, child) {
              final bool allTracksDownloaded = tracks.isNotEmpty && 
                  tracks.every((track) => appState.downloadService.isTrackDownloaded(track.id));
              
              if (allTracksDownloaded) {
                return const SizedBox.shrink();
              }
              
              return CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadAlbum();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.cloud_download, color: CupertinoColors.activeBlue),
                    SizedBox(width: 8),
                    Text('Download'),
                  ],
                ),
              );
            },
          ),
          // Mark as favorite
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _toggleAlbumFavorite(appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.heart, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Mark as favorite'),
              ],
            ),
          ),
          // Play next
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addToQueueNext(appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.text_insert, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Play next'),
              ],
            ),
          ),
          // Play later
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addToQueueLater(appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.text_append, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Play later'),
              ],
            ),
          ),
          // Instant mix
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createInstantMix(appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.antenna_radiowaves_left_right, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Instant mix'),
              ],
            ),
          ),
          // Add to collection/playlist
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Add to collection...'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _toggleAlbumFavorite(AppState appState) {
    // For now, just show a message since album favorite functionality needs to be implemented in AppState
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Favorite'),
        content: Text('Added album "${widget.album.name}" to favorites.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addToQueueNext(AppState appState) {
    if (tracks.isNotEmpty) {
      // Add tracks to queue one by one
      for (final track in tracks) {
        appState.addToQueue(track);
      }
      _showQueueMessage('Added album to play next');
    }
  }

  void _addToQueueLater(AppState appState) {
    if (tracks.isNotEmpty) {
      // Add tracks to queue one by one
      for (final track in tracks) {
        appState.addToQueue(track);
      }
      _showQueueMessage('Added album to queue');
    }
  }

  void _createInstantMix(AppState appState) {
    if (tracks.isNotEmpty) {
      // For now, just play the album shuffled as an instant mix
      final shuffledTracks = List<Track>.from(tracks)..shuffle();
      appState.playPlaylist(shuffledTracks, 0);
      _showQueueMessage('Created instant mix from album');
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, AppState appState) {
    final playlists = appState.playlists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Album to Playlist'),
        message: Text('Select a playlist to add "${widget.album.name}" to:'),
        actions: [
          // Show existing playlists
          ...playlists.map((playlist) => CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addAlbumToPlaylist(playlist, appState);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_list, color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          // Create new playlist option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createNewPlaylistWithAlbum(context, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Create New Playlist'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _addAlbumToPlaylist(dynamic playlist, AppState appState) async {
    try {
      int successCount = 0;
      for (final track in tracks) {
        final success = await appState.addToPlaylist(playlist.id, track.id);
        if (success) successCount++;
      }
      
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: Text('Added $successCount of ${tracks.length} songs from "${widget.album.name}" to "${playlist.name}".'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to add album to playlist: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _createNewPlaylistWithAlbum(BuildContext context, AppState appState) {
    final TextEditingController controller = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your new playlist:'),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Playlist name',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _createPlaylistWithAlbum(controller.text.trim(), appState);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createPlaylistWithAlbum(String playlistName, AppState appState) async {
    try {
      final success = await appState.createPlaylist(playlistName);
      
      if (success && context.mounted) {
        final newPlaylist = appState.playlists.firstWhere(
          (p) => p.name == playlistName,
          orElse: () => throw Exception('Playlist not found after creation'),
        );
        
        _addAlbumToPlaylist(newPlaylist, appState);
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create playlist: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showQueueMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _playTrack(Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(tracks, index);
  }

  String _formatTotalDuration() {
    if (tracks.isEmpty) return '0 minutes';
    
    int totalSeconds = 0;
    for (final track in tracks) {
      if (track.duration != null) {
        // Assuming duration is stored as seconds (int or double)
        totalSeconds += track.duration!.round();
      }
    }
    
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  void _playAllTracks() {
    if (tracks.isNotEmpty) {
      _playTrack(tracks.first, 0);
    }
  }

  void _shuffleAllTracks() {
    if (tracks.isNotEmpty) {
      final appState = context.read<AppState>();
      final shuffledTracks = List<Track>.from(tracks)..shuffle();
      appState.playPlaylist(shuffledTracks, 0);
    }
  }

  void _downloadAlbum() async {
    final appState = context.read<AppState>();
    
    if (tracks.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Empty Album'),
            content: Text('The album "${widget.album.name}" has no tracks to download.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // Show confirmation dialog
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Download Album'),
          content: Text(
            'Download "${widget.album.name}" with ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}?'
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Download'),
              onPressed: () {
                Navigator.of(context).pop();
                _startAlbumDownload(appState);
              },
            ),
          ],
        );
      },
    );
  }

  void _startAlbumDownload(AppState appState) async {
    int downloadedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    
    // Count already downloaded tracks
    for (final track in tracks) {
      if (appState.downloadService.isTrackDownloaded(track.id)) {
        skippedCount++;
      }
    }
    
    // Start downloading all tracks
    for (final track in tracks) {
      try {
        if (!appState.downloadService.isTrackDownloaded(track.id)) {
          await appState.downloadService.downloadTrack(track);
          downloadedCount++;
        }
      } catch (e) {
        failedCount++;
        if (kDebugMode) {
          print('Failed to start download for track ${track.name}: $e');
        }
      }
    }
    
    // Show completion message
    if (!mounted) return;
    String message;
    if (downloadedCount > 0) {
      message = 'Started downloading $downloadedCount ${downloadedCount == 1 ? 'song' : 'songs'}';
      if (skippedCount > 0) {
        message += ', $skippedCount already downloaded';
      }
      if (failedCount > 0) {
        message += ', $failedCount failed to start';
      }
    } else if (skippedCount > 0) {
      if (skippedCount == tracks.length) {
        message = 'All songs in "${widget.album.name}" are already downloaded';
      } else {
        message = '$skippedCount songs already downloaded';
      }
    } else {
      message = 'Failed to start downloads';
    }
    
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(downloadedCount > 0 || skippedCount == tracks.length ? 'Download Started' : 'Download Failed'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
