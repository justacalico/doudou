import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';

class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E), // Dark gray background instead of pure black
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildSectionHeader('Audio Settings'),

              _buildSwitchTile(
                icon: CupertinoIcons.speaker_2,
                title: 'Normalize Volume',
                subtitle: 'Reduces volume differences between tracks',
                value: appState.normalizeVolumeEnabled,
                onChanged: (value) {
                  appState.toggleNormalizeVolume(value);
                },
              ),
              _buildSwitchTile(
                icon: CupertinoIcons.forward_end,
                title: 'Gapless Playback',
                subtitle: 'Seamless transitions between tracks in queue',
                value: appState.gaplessPlaybackEnabled,
                onChanged: (value) {
                  appState.toggleGaplessPlayback(value);
                },
              ),
              const Divider(
                color: Color(0xFF2C2C2E),
                height: 1,
                indent: 20,
                endIndent: 20,
              ),
              _buildDownloadTile(
                context: context,
                icon: CupertinoIcons.cloud_download,
                title: 'Download All Songs',
                subtitle: 'Download your entire music library',
                onTap: () => _downloadAllSongs(context, appState),
              ),
              _buildDownloadTile(
                context: context,
                icon: CupertinoIcons.heart_circle,
                title: 'Download All Favorites',
                subtitle: 'Download all your liked songs',
                onTap: () => _downloadAllFavorites(context, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFFFFF), // Pure white text
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFF30D158) : const Color(0xFF007AFF), // Green when active, blue when inactive
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
                    color: Color(0xFFFFFFFF), // Pure white text
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA), // Lighter gray
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF30D158), // Green for OLED
            trackColor: const Color(0xFF1C1C1E), // Dark track
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3A3A3C),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF007AFF), // Blue accent
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
                      color: Color(0xFFFFFFFF), // Pure white text
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA), // Lighter gray
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF666666),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadAllSongs(BuildContext context, AppState appState) {
    final totalSongs = appState.tracks.length;
    final downloadedCount = appState.tracks.where((track) => appState.downloadService.isTrackDownloaded(track.id)).length;
    final remainingSongs = totalSongs - downloadedCount;

    if (remainingSongs == 0) {
      _showInfoDialog(
        context,
        'All Songs Downloaded',
        'All your songs are already downloaded.',
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Download All Songs'),
        content: Text(
          'Download all $totalSongs songs in your library?\n\n'
          '${downloadedCount > 0 ? '$downloadedCount already downloaded, ' : ''}'
          '$remainingSongs songs will be downloaded.',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _startBulkDownload(context, appState, appState.tracks, 'all songs');
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _downloadAllFavorites(BuildContext context, AppState appState) {
    final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();
    
    if (favoriteTracks.isEmpty) {
      _showInfoDialog(
        context,
        'No Favorite Songs',
        'You haven\'t marked any songs as favorites yet. Tap the heart icon on songs to add them to your favorites.',
      );
      return;
    }

    final downloadedCount = favoriteTracks.where((track) => appState.downloadService.isTrackDownloaded(track.id)).length;
    final remainingFavorites = favoriteTracks.length - downloadedCount;

    if (remainingFavorites == 0) {
      _showInfoDialog(
        context,
        'All Favorites Downloaded',
        'All your favorite songs are already downloaded.',
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Download All Favorites'),
        content: Text(
          'Download all ${favoriteTracks.length} favorite songs?\n\n'
          '${downloadedCount > 0 ? '$downloadedCount already downloaded, ' : ''}'
          '$remainingFavorites songs will be downloaded.',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _startBulkDownload(context, appState, favoriteTracks, 'favorite songs');
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _startBulkDownload(BuildContext context, AppState appState, List<dynamic> tracks, String description) async {
    int downloadedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;

    // Show progress dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text('Starting Downloads'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('Preparing downloads...'),
          ],
        ),
      ),
    );

    // Start downloads (don't await - let them run in background)
    for (final track in tracks) {
      try {
        if (!appState.downloadService.isTrackDownloaded(track.id)) {
          // Start download without awaiting (fire and forget)
          appState.downloadService.downloadTrack(track).catchError((error) {
            // Handle individual download errors silently
            return;
          });
          downloadedCount++;
        } else {
          skippedCount++;
        }
      } catch (e) {
        failedCount++;
      }
    }

    // Close progress dialog immediately
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Show completion message
    if (context.mounted) {
      String message = '';
      if (downloadedCount > 0) {
        message = 'Started downloading $downloadedCount ${downloadedCount == 1 ? 'song' : 'songs'}';
        if (skippedCount > 0) {
          message += ', $skippedCount already downloaded';
        }
        if (failedCount > 0) {
          message += ', $failedCount failed to start';
        }
        message += '\n\nDownloads will continue in the background. Check the Downloads tab to monitor progress.';
      } else if (skippedCount > 0) {
        message = 'All $description are already downloaded';
      } else {
        message = 'Failed to start downloads';
      }

      _showInfoDialog(
        context,
        downloadedCount > 0 ? 'Downloads Started' : 'Download Status',
        message,
      );
    }
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
