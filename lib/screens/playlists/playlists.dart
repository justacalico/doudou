import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../partials/player/mini_player.dart';

class PlaylistsView extends StatelessWidget {
  const PlaylistsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.playlists.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

        if (appState.playlists.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.music_note_list,
                  size: 64,
                  color: CupertinoColors.systemGrey,
                ),
                SizedBox(height: 16),
                Text(
                  'No playlists found',
                  style: TextStyle(
                    fontSize: 18,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Container(
              color: const Color(0xFF000000), // Dark background
              child: CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () => appState.loadLibraryData(),
                  ),
                  // Create playlist button
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      child: CupertinoButton.filled(
                        onPressed: () => _showCreatePlaylistDialog(context, appState),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.add, size: 18),
                            SizedBox(width: 8),
                            Text('Create Playlist'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Playlists list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = appState.playlists[index];
                        return PlaylistTile(
                          playlist: playlist,
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => PlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        );
                      },
                      childCount: appState.playlists.length,
                    ),
                  ),
                  // Add some bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
            // Mini player at bottom
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, AppState appState) {
    final TextEditingController nameController = TextEditingController();
    
    showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Create Playlist'),
          content: Container(
            margin: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: nameController,
              placeholder: 'Playlist name',
              style: const TextStyle(color: CupertinoColors.black),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              autofocus: true,
            ),
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
              child: const Text('Create'),
              onPressed: () {
                final playlistName = nameController.text.trim();
                if (playlistName.isNotEmpty) {
                  _createPlaylist(context, appState, playlistName);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _createPlaylist(BuildContext context, AppState appState, String name) async {
    // Close the dialog first
    Navigator.of(context).pop();
    
    // Show loading indicator
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const CupertinoAlertDialog(
          title: Text('Creating Playlist'),
          content: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );
    
    try {
      final success = await appState.createPlaylist(name);
      
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      if (success) {
        // Show success message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Success'),
              content: Text('Playlist "$name" created successfully!'),
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
      } else {
        // Show error message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to create playlist "$name". Please try again.'),
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
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      // Show error message
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: ${e.toString()}'),
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
}

class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const PlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return GestureDetector(
          onTap: onTap,
          onLongPress: () => _showPlaylistOptions(context, appState),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Playlist artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: playlist.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: appState.jellyfinService.getImageUrl(
                              playlist.imageUrl!,
                              width: 150,
                              height: 150,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF2C2C2E),
                              child: const Icon(
                                CupertinoIcons.music_note_list,
                                color: CupertinoColors.systemGrey,
                                size: 24,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF2C2C2E),
                              child: const Icon(
                                CupertinoIcons.music_note_list,
                                color: CupertinoColors.systemGrey,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(
                              CupertinoIcons.music_note_list,
                              color: CupertinoColors.systemGrey,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Playlist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'}',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation arrow
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaylistOptions(BuildContext context, AppState appState) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          playlist.name,
          style: const TextStyle(fontSize: 16),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _downloadPlaylist(context, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.cloud_download, size: 18),
                SizedBox(width: 8),
                Text('Download Playlist'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showRenameDialog(context, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 18),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete, size: 18),
                SizedBox(width: 8),
                Text('Remove'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _downloadPlaylist(BuildContext context, AppState appState) async {
    // Show loading indicator
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const CupertinoAlertDialog(
          title: Text('Loading Playlist'),
          content: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );
    
    try {
      // First, get all tracks in the playlist
      final tracks = await appState.getPlaylistTracks(playlist.id);
      
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      if (tracks.isEmpty) {
        // Show empty playlist message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Empty Playlist'),
              content: Text('The playlist "${playlist.name}" is empty.'),
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
      
      // Show confirmation dialog with track count
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Download Playlist'),
            content: Text(
              'Download "${playlist.name}" with ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}?'
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
                  _startPlaylistDownload(context, appState, tracks);
                },
              ),
            ],
          );
        },
      );
      
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      // Show error message
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load playlist tracks: ${e.toString()}'),
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

  void _startPlaylistDownload(BuildContext context, AppState appState, List<Track> tracks) async {
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
    if (!context.mounted) return;
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
      message = 'All songs in "${playlist.name}" are already downloaded';
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

  void _showRenameDialog(BuildContext context, AppState appState) {
    final TextEditingController nameController = TextEditingController(text: playlist.name);
    
    showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Rename Playlist'),
          content: Container(
            margin: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: nameController,
              placeholder: 'Playlist name',
              style: const TextStyle(color: CupertinoColors.black),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              autofocus: true,
            ),
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
              child: const Text('Rename'),
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != playlist.name) {
                  _renamePlaylist(context, appState, newName);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppState appState) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Remove Playlist'),
          content: Text('Are you sure you want to remove "${playlist.name}"? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Remove'),
              onPressed: () {
                _removePlaylist(context, appState);
              },
            ),
          ],
        );
      },
    );
  }

  void _renamePlaylist(BuildContext context, AppState appState, String newName) async {
    // Close the dialog first
    Navigator.of(context).pop();
    
    // Show loading indicator
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const CupertinoAlertDialog(
          title: Text('Renaming Playlist'),
          content: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );
    
    try {
      final success = await appState.renamePlaylist(playlist.id, newName);
      
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      if (success) {
        // Show success message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Success'),
              content: Text('Playlist renamed to "$newName" successfully!'),
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
      } else {
        // Show error message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to rename playlist to "$newName". Please try again.'),
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
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      // Show error message
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: ${e.toString()}'),
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

  void _removePlaylist(BuildContext context, AppState appState) async {
    // Close the dialog first
    Navigator.of(context).pop();
    
    // Show loading indicator
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const CupertinoAlertDialog(
          title: Text('Removing Playlist'),
          content: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );
    
    try {
      final success = await appState.removePlaylist(playlist.id);
      
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      if (success) {
        // Show success message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Success'),
              content: Text('Playlist "${playlist.name}" removed successfully!'),
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
      } else {
        // Show error message
        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to remove playlist "${playlist.name}". Please try again.'),
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
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      // Show error message
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: ${e.toString()}'),
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
}

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Track> tracks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    
    try {
      if (kDebugMode) {
        print('Loading tracks for playlist: ${widget.playlist.id}');
      }
      
      final playlistTracks = await appState.getPlaylistTracks(widget.playlist.id);
      
      if (kDebugMode) {
        print('Loaded ${playlistTracks.length} tracks for playlist: ${widget.playlist.name}');
      }
      
      setState(() {
        tracks = playlistTracks;
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading playlist tracks: $e');
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.playlist.name,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        border: null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _refreshTracks,
                ),
                // Playlist header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Playlist artwork
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: widget.playlist.imageUrl != null
                                ? Consumer<AppState>(
                                    builder: (context, appState, child) {
                                      return CachedNetworkImage(
                                        imageUrl: appState.jellyfinService.getImageUrl(
                                          widget.playlist.imageUrl!,
                                          width: 400,
                                          height: 400,
                                        ),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: const Color(0xFF2C2C2E),
                                          child: const Icon(
                                            CupertinoIcons.music_note_list,
                                            color: CupertinoColors.systemGrey,
                                            size: 48,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: const Color(0xFF2C2C2E),
                                          child: const Icon(
                                            CupertinoIcons.music_note_list,
                                            color: CupertinoColors.systemGrey,
                                            size: 48,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFF2C2C2E),
                                    child: const Icon(
                                      CupertinoIcons.music_note_list,
                                      color: CupertinoColors.systemGrey,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Playlist name
                        Text(
                          widget.playlist.name,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Track count
                        Text(
                          '${widget.playlist.trackCount} ${widget.playlist.trackCount == 1 ? 'song' : 'songs'}',
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Play buttons
                        if (tracks.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.filled(
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.play_fill, size: 18),
                                      SizedBox(width: 8),
                                      Text('Play'),
                                    ],
                                  ),
                                  onPressed: () => _playAllTracks(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CupertinoButton(
                                  color: const Color(0xFF2C2C2E),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.shuffle, size: 18),
                                      SizedBox(width: 8),
                                      Text('Shuffle'),
                                    ],
                                  ),
                                  onPressed: () => _shuffleAllTracks(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Download button
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: const Color(0xFF007AFF),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.cloud_download, size: 18),
                                  SizedBox(width: 8),
                                  Text('Download Playlist'),
                                ],
                              ),
                              onPressed: () => _downloadPlaylistDetail(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Loading or tracks list
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CupertinoActivityIndicator(color: CupertinoColors.white),
                    ),
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
                            color: CupertinoColors.systemGrey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No tracks in this playlist',
                            style: TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = tracks[index];
                        return PlaylistTrackItem(
                          track: track,
                          trackNumber: index + 1,
                          onTap: () => _playTrack(track, index),
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),
                // Add some bottom padding for mini player
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

  void _playTrack(Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(tracks, index);
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
}

class PlaylistTrackItem extends StatelessWidget {
  final Track track;
  final int trackNumber;
  final VoidCallback onTap;

  const PlaylistTrackItem({
    super.key,
    required this.track,
    required this.trackNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Track number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    trackNumber.toString(),
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Album artwork (small)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: track.imageUrl != null
                      ? Consumer<AppState>(
                          builder: (context, appState, child) {
                            return CachedNetworkImage(
                              imageUrl: appState.jellyfinService.getImageUrl(
                                track.imageUrl!,
                                width: 100,
                                height: 100,
                              ),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  CupertinoIcons.music_note,
                                  color: CupertinoColors.systemGrey,
                                  size: 16,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  CupertinoIcons.music_note,
                                  color: CupertinoColors.systemGrey,
                                  size: 16,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.systemGrey,
                            size: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        track.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Duration
              if (track.duration != null) ...[
                Text(
                  _formatDuration(Duration(milliseconds: track.duration!)),
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
