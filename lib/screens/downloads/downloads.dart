import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/download_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/download_service.dart';
import '../partials/player/mini_player.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return Container(
          color: const Color(0xFF000000),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  color: Color(0xFF007AFF),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Downloads',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Offline music',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Settings button
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _showDownloadSettings(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF333333),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.gear,
                                    color: Color(0xFF8E8E93),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Tab selector
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            child: CupertinoSlidingSegmentedControl<int>(
                              groupValue: _tabController.index,
                              onValueChanged: (value) {
                                if (value != null) {
                                  _tabController.animateTo(value);
                                  setState(() {});
                                }
                              },
                              children: const {
                                0: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Playlists'),
                                ),
                                1: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Songs'),
                                ),
                                2: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Queue'),
                                ),
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content based on selected tab
                  if (_tabController.index == 0)
                    _buildDownloadedPlaylists(downloadService, appState)
                  else if (_tabController.index == 1)
                    _buildDownloadedSongs(downloadService, appState)
                  else
                    _buildDownloadQueue(downloadService),
                  
                  // Bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
              
              // Mini player
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadedPlaylists(DownloadService downloadService, AppState appState) {
    final downloadedTracks = downloadService.downloadedTracks;
    
    if (downloadedTracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.music_note_list,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded playlists',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Download playlists to listen offline',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group downloaded tracks by playlist
    final playlistGroups = _groupTracksByPlaylist(downloadedTracks, appState);
    
    if (playlistGroups.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.music_note_list,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded playlists',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Downloaded songs that are part of playlists will appear here',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlistEntry = playlistGroups.entries.elementAt(index);
          final playlist = playlistEntry.key;
          final tracks = playlistEntry.value;
          
          return DownloadedPlaylistItem(
            playlist: playlist,
            downloadedTracks: tracks,
            onTap: () => _showPlaylistTracks(context, playlist, tracks, appState),
            onDelete: () => _deletePlaylistDownloads(downloadService, tracks),
          );
        },
        childCount: playlistGroups.length,
      ),
    );
  }

  Widget _buildDownloadedSongs(DownloadService downloadService, AppState appState) {
    final downloadedTracks = downloadService.downloadedTracks;
    
    if (downloadedTracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded songs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Download songs to listen offline',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final trackId = downloadedTracks.keys.elementAt(index);
          final downloadedTrack = downloadedTracks[trackId]!;
          final track = appState.tracks.firstWhere(
            (t) => t.id == trackId,
            orElse: () => Track(
              id: trackId,
              name: 'Unknown Track',
            ),
          );
          
          return DownloadedTrackItem(
            track: track,
            downloadedTrack: downloadedTrack,
            onTap: () => _playDownloadedTrack(appState, track),
            onDelete: () => _deleteDownload(downloadService, trackId),
          );
        },
        childCount: downloadedTracks.length,
      ),
    );
  }

  // Helper method to group tracks by playlist
  Map<Playlist, List<Track>> _groupTracksByPlaylist(Map<String, DownloadedTrack> downloadedTracks, AppState appState) {
    final Map<Playlist, List<Track>> playlistGroups = {};
    
    // Get all downloaded track IDs
    final downloadedTrackIds = downloadedTracks.keys.toSet();
    
    // Check each playlist to see if it has downloaded tracks
    for (final playlist in appState.playlists) {
      final playlistTracks = <Track>[];
      
      // Check which tracks from this playlist are downloaded
      for (final track in appState.tracks) {
        if (downloadedTrackIds.contains(track.id)) {
          // Check if this track belongs to the playlist
          // Note: This is a simplified check. In a real app, you'd need to 
          // track playlist membership more explicitly
          playlistTracks.add(track);
        }
      }
      
      if (playlistTracks.isNotEmpty) {
        playlistGroups[playlist] = playlistTracks;
      }
    }
    
    return playlistGroups;
  }

  void _showPlaylistTracks(BuildContext context, Playlist playlist, List<Track> tracks, AppState appState) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DownloadedPlaylistDetailScreen(
          playlist: playlist,
          downloadedTracks: tracks,
        ),
      ),
    );
  }

  void _deletePlaylistDownloads(DownloadService downloadService, List<Track> tracks) {
    for (final track in tracks) {
      downloadService.deleteDownload(track.id);
    }
  }

  Widget _buildDownloadQueue(DownloadService downloadService) {
    final downloadTasks = downloadService.downloadTasks;
    
    if (downloadTasks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloads in queue',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Add songs to download queue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final task = downloadTasks[index];
          return DownloadTaskItem(
            task: task,
            onCancel: () => downloadService.cancelDownload(task.trackId),
            onRetry: () => _retryDownload(downloadService, task),
          );
        },
        childCount: downloadTasks.length,
      ),
    );
  }

  void _playDownloadedTrack(AppState appState, Track track) {
    // Create a playlist with just this track for now
    // In a real implementation, you might want to play all downloaded tracks
    appState.playPlaylist([track], 0);
  }

  void _deleteDownload(DownloadService downloadService, String trackId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Download'),
        content: const Text('Are you sure you want to delete this downloaded song?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              downloadService.deleteDownload(trackId);
            },
          ),
        ],
      ),
    );
  }

  void _retryDownload(DownloadService downloadService, DownloadTask task) {
    if (kDebugMode) {
      print('_retryDownload called for task: ${task.trackName}, status: ${task.status}');
    }
    
    // Find the track and retry download
    final appState = context.read<AppState>();
    final track = appState.tracks.firstWhere(
      (t) => t.id == task.trackId,
      orElse: () => Track(
        id: task.trackId,
        name: task.trackName,
        artistName: task.artistName,
        albumName: task.albumName,
        imageUrl: task.imageUrl,
      ),
    );
    
    if (kDebugMode) {
      print('Retrying download for track: ${track.name}');
    }
    
    downloadService.downloadTrack(track);
  }

  void _showDownloadSettings(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const DownloadSettingsSheet(),
    );
  }
}

class DownloadedTrackItem extends StatelessWidget {
  final Track track;
  final DownloadedTrack downloadedTrack;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DownloadedTrackItem({
    super.key,
    required this.track,
    required this.downloadedTrack,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Album artwork
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: downloadedTrack.imagePath != null
                      ? Image.file(
                          File(downloadedTrack.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            CupertinoIcons.music_note,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        )
                      : track.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: context
                                  .read<AppState>()
                                  .jellyfinService
                                  .getImageUrl(
                                    track.imageUrl!,
                                    width: 112,
                                    height: 112,
                                  ),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CupertinoActivityIndicator(
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                CupertinoIcons.music_note,
                                color: Color(0xFF8E8E93),
                                size: 28,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFF8E8E93),
                              size: 28,
                            ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.artistName!,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.arrow_down_circle_fill,
                          color: Color(0xFF00FF88),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(downloadedTrack.fileSize),
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Delete button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.trash,
                    color: Color(0xFFFF453A),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DownloadTaskItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const DownloadTaskItem({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF1C1C1E),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                  width: 1,
                ),
              ),
              child: Center(
                child: _buildStatusIcon(),
              ),
            ),
            const SizedBox(width: 16),
            
            // Track info and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.trackName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                      fontSize: 16,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.artistName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.artistName!,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  
                  // Progress bar and status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: task.progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(task.progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action button
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused) ? onRetry : onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: Icon(
                  (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused)
                      ? CupertinoIcons.refresh
                      : CupertinoIcons.xmark,
                  color: (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused)
                      ? const Color(0xFF007AFF)
                      : const Color(0xFF8E8E93),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return const CupertinoActivityIndicator(
          color: Color(0xFF007AFF),
        );
      case DownloadStatus.failed:
        return const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: Color(0xFFFF453A),
          size: 24,
        );
      case DownloadStatus.paused:
        return const Icon(
          CupertinoIcons.pause,
          color: Color(0xFF8E8E93),
          size: 24,
        );
      default:
        return const Icon(
          CupertinoIcons.clock,
          color: Color(0xFF8E8E93),
          size: 24,
        );
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return const Color(0xFF007AFF);
      case DownloadStatus.failed:
        return const Color(0xFFFF453A);
      case DownloadStatus.paused:
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.downloading:
        if (task.totalBytes != null && task.downloadedBytes != null) {
          return '${_formatFileSize(task.downloadedBytes!)} / ${_formatFileSize(task.totalBytes!)}';
        }
        return 'Downloading...';
      case DownloadStatus.failed:
        return task.errorMessage ?? 'Download failed';
      case DownloadStatus.paused:
        return 'Cancelled - Tap to retry';
      default:
        return 'Waiting...';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DownloadSettingsSheet extends StatelessWidget {
  const DownloadSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E8E93),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Download Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
              
              // Settings options
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingsItem(
                      context,
                      'Clear All Downloads',
                      'Remove all downloaded music',
                      CupertinoIcons.trash,
                      const Color(0xFFFF453A),
                      () => _showClearAllDialog(context, downloadService),
                    ),
                    
                    _buildStorageInfo(downloadService),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF8E8E93),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageInfo(DownloadService downloadService) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Storage Usage',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: downloadService.getTotalDownloadedSize(),
            builder: (context, snapshot) {
              final totalSize = snapshot.data ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloaded: ${_formatFileSize(totalSize)}',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Songs: ${downloadService.downloadedTracks.length}',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, DownloadService downloadService) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Downloads'),
        content: const Text(
          'This will delete all downloaded music from your device. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear All'),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings sheet
              downloadService.clearAllDownloads();
            },
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// New widget for downloaded playlist items
class DownloadedPlaylistItem extends StatelessWidget {
  final Playlist playlist;
  final List<Track> downloadedTracks;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DownloadedPlaylistItem({
    super.key,
    required this.playlist,
    required this.downloadedTracks,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Playlist artwork
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: playlist.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: context
                              .read<AppState>()
                              .jellyfinService
                              .getImageUrl(
                                playlist.imageUrl!,
                                width: 112,
                                height: 112,
                              ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CupertinoActivityIndicator(
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.music_note_list,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.music_note_list,
                          color: Color(0xFF8E8E93),
                          size: 28,
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
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Download indicator and delete button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF30D158).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: Color(0xFF30D158),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 24,
                    onPressed: onDelete,
                    child: const Icon(
                      CupertinoIcons.delete,
                      color: Color(0xFFFF453A),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New screen for showing downloaded playlist details
class DownloadedPlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  final List<Track> downloadedTracks;

  const DownloadedPlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.downloadedTracks,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          playlist.name,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
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
                        child: playlist.imageUrl != null
                            ? Consumer<AppState>(
                                builder: (context, appState, child) {
                                  return CachedNetworkImage(
                                    imageUrl: appState.jellyfinService.getImageUrl(
                                      playlist.imageUrl!,
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
                      playlist.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Downloaded track count
                    Text(
                      '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Play button
                    if (downloadedTracks.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 18),
                              SizedBox(width: 8),
                              Text('Play Downloaded'),
                            ],
                          ),
                          onPressed: () => _playDownloadedTracks(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Downloaded tracks list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = downloadedTracks[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _playTrack(context, track, index),
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
                                  (index + 1).toString(),
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Downloaded indicator
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: Color(0xFF30D158),
                              size: 16,
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: downloadedTracks.length,
              ),
            ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _playDownloadedTracks(BuildContext context) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, 0);
  }

  void _playTrack(BuildContext context, Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, index);
  }
}
