import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../l10n/app_localizations.dart';

class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSectionHeader(l10n.audioSettings),

                    _buildSwitchTile(
                      icon: CupertinoIcons.speaker_2,
                      title: l10n.normalizeVolume,
                      subtitle: l10n.reduceVolumeDifferences,
                      value: appState.normalizeVolumeEnabled,
                      onChanged: (value) {
                        appState.toggleNormalizeVolume(value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: CupertinoIcons.forward_end,
                      title: l10n.gaplessPlayback,
                      subtitle: l10n.seamlessTransitions,
                      value: appState.gaplessPlaybackEnabled,
                      onChanged: (value) {
                        appState.toggleGaplessPlayback(value);
                      },
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _buildDownloadTile(
                      context: context,
                      icon: CupertinoIcons.cloud_download,
                      title: l10n.downloadAllSongs,
                      subtitle: l10n.downloadEntireLibrary,
                      onTap: () => _downloadAllSongs(context, appState),
                    ),
                    _buildDownloadTile(
                      context: context,
                      icon: CupertinoIcons.heart_circle,
                      title: l10n.downloadAllFavorites,
                      subtitle: l10n.downloadAllLikedSongs,
                      onTap: () => _downloadAllFavorites(context, appState),
                    ),
                  ],
                ),
              ),
            ),
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
              color: value
                  ? const Color(0xFFEC4899).withOpacity(0.15)
                  : const Color(0xFF8B5CF6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? const Color(0xFFEC4899).withOpacity(0.3)
                    : const Color(0xFF8B5CF6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFEC4899),
            trackColor: Colors.white.withOpacity(0.1),
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
                color: const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: const Color(0xFF06B6D4), size: 20),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadAllSongs(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    final totalSongs = appState.tracks.length;
    final downloadedCount = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .length;
    final remainingSongs = totalSongs - downloadedCount;

    if (remainingSongs == 0) {
      _showInfoDialog(
        context,
        l10n.allSongsDownloaded,
        l10n.allSongsAlreadyDownloaded,
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.downloadAllSongs),
        content: Text(
          '${l10n.downloadAllSongsConfirm(totalSongs)}\n\n'
          '${downloadedCount > 0 ? '${l10n.alreadyDownloadedCount(downloadedCount)}, ' : ''}'
          '${l10n.songsWillBeDownloaded(remainingSongs)}',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _startBulkDownload(
                context,
                appState,
                appState.tracks,
                l10n.songs,
              );
            },
            child: Text(l10n.download),
          ),
        ],
      ),
    );
  }

  void _downloadAllFavorites(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    final favoriteTracks = appState.tracks
        .where((track) => track.isFavorite)
        .toList();

    if (favoriteTracks.isEmpty) {
      _showInfoDialog(context, l10n.noFavoriteSongs, l10n.noFavoriteSongsYet);
      return;
    }

    final downloadedCount = favoriteTracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .length;
    final remainingFavorites = favoriteTracks.length - downloadedCount;

    if (remainingFavorites == 0) {
      _showInfoDialog(
        context,
        l10n.allFavoritesDownloaded,
        l10n.allFavoritesAlreadyDownloaded,
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.downloadAllFavorites),
        content: Text(
          '${l10n.downloadAllFavoritesConfirm(favoriteTracks.length)}\n\n'
          '${downloadedCount > 0 ? '${l10n.alreadyDownloadedCount(downloadedCount)}, ' : ''}'
          '${l10n.songsWillBeDownloaded(remainingFavorites)}',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _startBulkDownload(
                context,
                appState,
                favoriteTracks,
                l10n.favorites,
              );
            },
            child: Text(l10n.download),
          ),
        ],
      ),
    );
  }

  void _startBulkDownload(
    BuildContext context,
    AppState appState,
    List<dynamic> tracks,
    String description,
  ) async {
    final l10n = AppLocalizations.of(context);
    int downloadedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;

    // Show progress dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.startingDownloads),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CupertinoActivityIndicator(),
            const SizedBox(height: 16),
            Text(l10n.preparingDownloads),
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
      final l10nAfter = AppLocalizations.of(context);
      String message = '';
      if (downloadedCount > 0) {
        message = l10nAfter.startedDownloading(
          downloadedCount,
          downloadedCount == 1 ? l10nAfter.song : l10nAfter.songs,
        );
        if (skippedCount > 0) {
          message += ', ${l10nAfter.alreadyDownloadedCount(skippedCount)}';
        }
        if (failedCount > 0) {
          message += ', ${l10nAfter.failedToStart(failedCount)}';
        }
        message += '\n\n${l10nAfter.downloadsContinueInBackground}';
      } else if (skippedCount > 0) {
        message = l10nAfter.allAlreadyDownloaded(description);
      } else {
        message = l10nAfter.failedToStartDownloads;
      }

      _showInfoDialog(
        context,
        downloadedCount > 0
            ? l10nAfter.downloadsStarted
            : l10nAfter.downloadStatus,
        message,
      );
    }
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
