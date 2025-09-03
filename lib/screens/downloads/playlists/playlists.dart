import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/app_state.dart';
import '../../../models/download_models.dart';
import '../../../models/jellyfin_models.dart';
import '../../../services/download_service.dart';
import '../../playlists/playlists.dart';

class DownloadedPlaylistsTab extends StatefulWidget {
  const DownloadedPlaylistsTab({super.key});

  @override
  State<DownloadedPlaylistsTab> createState() => _DownloadedPlaylistsTabState();
}

class _DownloadedPlaylistsTabState extends State<DownloadedPlaylistsTab> {
  Map<Playlist, List<Track>>? _cachedPlaylistGroups;
  bool _isLoadingPlaylists = false;
  int _lastDownloadedTracksCount = 0;

  @override
  void didUpdateWidget(DownloadedPlaylistsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cached data when the widget updates, which happens when downloads change
    _cachedPlaylistGroups = null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return _buildDownloadedPlaylists(downloadService, appState);
      },
    );
  }

  Widget _buildDownloadedPlaylists(DownloadService downloadService, AppState appState) {
    final downloadedTracks = downloadService.downloadedTracks;
    
    // Check if the number of downloaded tracks has changed, and invalidate cache if so
    if (downloadedTracks.length != _lastDownloadedTracksCount) {
      if (kDebugMode) {
        print('Downloads count changed from $_lastDownloadedTracksCount to ${downloadedTracks.length}, invalidating playlist cache');
      }
      _lastDownloadedTracksCount = downloadedTracks.length;
      _cachedPlaylistGroups = null; // Invalidate cache
    }
    
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

    // Check if we need to refresh the playlist groups
    if (_cachedPlaylistGroups == null && !_isLoadingPlaylists) {
      // Schedule the load to happen after the current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadPlaylistGroups(downloadedTracks, appState);
        }
      });
    }

    // Show loading state while fetching playlist data
    if (_isLoadingPlaylists && _cachedPlaylistGroups == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          ),
        ),
      );
    }

    final playlistGroups = _cachedPlaylistGroups ?? {};
    
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

  // Method to load playlist groups asynchronously
  Future<void> _loadPlaylistGroups(Map<String, DownloadedTrack> downloadedTracks, AppState appState) async {
    if (_isLoadingPlaylists) return; // Prevent multiple concurrent loads
    
    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      final Map<Playlist, List<Track>> playlistGroups = {};
      
      // Get all downloaded track IDs
      final downloadedTrackIds = downloadedTracks.keys.toSet();
      
      if (kDebugMode) {
        print('Loading playlist groups for ${downloadedTrackIds.length} downloaded tracks');
      }
      
      // Check each playlist to see if it has downloaded tracks
      for (final playlist in appState.playlists) {
        try {
          // Actually fetch the playlist tracks from the server
          final playlistTracks = await appState.getPlaylistTracks(playlist.id);
          
          // Filter to only include downloaded tracks
          final downloadedPlaylistTracks = playlistTracks
              .where((track) => downloadedTrackIds.contains(track.id))
              .toList();
          
          if (downloadedPlaylistTracks.isNotEmpty) {
            playlistGroups[playlist] = downloadedPlaylistTracks;
            if (kDebugMode) {
              print('Found ${downloadedPlaylistTracks.length} downloaded tracks in playlist: ${playlist.name}');
            }
          }
        } catch (e) {
          // Skip this playlist if there's an error
          if (kDebugMode) {
            print('Error loading tracks for playlist ${playlist.name}: $e');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _cachedPlaylistGroups = playlistGroups;
          _isLoadingPlaylists = false;
        });
        
        if (kDebugMode) {
          print('Successfully loaded ${playlistGroups.length} playlist groups');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading playlist groups: $e');
      }
      if (mounted) {
        setState(() {
          _cachedPlaylistGroups = {};
          _isLoadingPlaylists = false;
        });
      }
    }
  }

  void _showPlaylistTracks(BuildContext context, Playlist playlist, List<Track> tracks, AppState appState) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  void _deletePlaylistDownloads(DownloadService downloadService, List<Track> tracks) {
    for (final track in tracks) {
      downloadService.deleteDownload(track.id);
    }
  }
}

// Widget for downloaded playlist items
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


