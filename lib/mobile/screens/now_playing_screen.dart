import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showQueue = false;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        if (audioHandler == null) {
          return _buildEmptyState(context);
        }

        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, snapshot) {
            final currentTrack = snapshot.data ?? audioHandler.currentTrack;
            if (currentTrack == null) {
              return _buildEmptyState(context);
            }

            return CupertinoPageScaffold(
              backgroundColor: AppTheme.backgroundDark,
              child: Stack(
                children: [
                  // Background with blur
                  if (currentTrack.imageUrl != null)
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                appState.getImageUrl(
                                  currentTrack.imageUrl!,
                                  width: 400,
                                  height: 400,
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // Dark overlay
                  Positioned.fill(
                    child: Container(
                      color: AppTheme.backgroundDark.withOpacity(0.7),
                    ),
                  ),

                  // Content
                  SafeArea(
                    child: _showQueue
                        ? _buildQueueView(context, appState, currentTrack)
                        : _buildPlayerView(context, appState, currentTrack),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Now Playing'),
        backgroundColor: AppTheme.background(context),
        border: null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.music_note,
              size: 64,
              color: AppTheme.textSecondary(context),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Not Playing',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle3,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Play something to see it here',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView(BuildContext context, AppState appState, Track currentTrack) {
    final audioHandler = appState.audioHandler!;
    final screenWidth = MediaQuery.of(context).size.width;
    final artworkSize = screenWidth - 100;

    return Column(
      children: [
        // Header row with chevron and airplay
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chevron down button
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minSize: 0,
                  onPressed: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    color: CupertinoColors.white.withOpacity(0.9),
                    size: 20,
                  ),
                ),
              ),
              // AirPlay button
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minSize: 0,
                  onPressed: () {},
                  child: Icon(
                    CupertinoIcons.antenna_radiowaves_left_right,
                    color: CupertinoColors.white.withOpacity(0.9),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Album artwork
        Container(
          width: artworkSize,
          height: artworkSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CachedArtwork(
            imageUrl: currentTrack.imageUrl != null
                ? appState.getImageUrl(currentTrack.imageUrl!, width: 600, height: 600)
                : null,
            size: artworkSize,
            borderRadius: AppTheme.radiusL,
          ),
        ),

        const Spacer(flex: 2),

        // Track info centered
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Column(
            children: [
              Text(
                currentTrack.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                currentTrack.artistName ?? 'Unknown Artist',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.white.withOpacity(0.6),
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Progress bar (full width)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: StreamBuilder<Duration>(
            stream: appState.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = currentTrack.duration != null
                  ? Duration(milliseconds: currentTrack.duration!)
                  : Duration.zero;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;

              return Column(
                children: [
                  // Custom thin progress bar
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.globalPosition);
                      final newProgress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                      final newPosition = Duration(
                        milliseconds: (newProgress * duration.inMilliseconds).round(),
                      );
                      audioHandler.seek(newPosition);
                    },
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.globalPosition);
                      final newProgress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                      final newPosition = Duration(
                        milliseconds: (newProgress * duration.inMilliseconds).round(),
                      );
                      audioHandler.seek(newPosition);
                    },
                    child: Container(
                      height: 20,
                      alignment: Alignment.center,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: CupertinoColors.white.withOpacity(0.2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentPink,
                                  AppTheme.accentPink.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withOpacity(0.5),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withOpacity(0.5),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              StreamBuilder<bool>(
                stream: audioHandler.shuffleEnabledStream,
                builder: (context, snapshot) {
                  final isShuffling = snapshot.data ?? false;
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => audioHandler.toggleShuffle(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isShuffling ? AppTheme.accentPink.withOpacity(0.2) : CupertinoColors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CupertinoIcons.shuffle,
                        size: 24,
                        color: isShuffling
                            ? AppTheme.accentPink
                            : CupertinoColors.white,
                      ),
                    ),
                  );
                },
              ),

              // Previous
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => audioHandler.skipToPrevious(),
                child: const Icon(
                  CupertinoIcons.backward_fill,
                  size: 40,
                  color: CupertinoColors.white,
                ),
              ),

              // Play/Pause
              StreamBuilder<PlayerState>(
                stream: appState.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accentPink,
                            AppTheme.accentPink.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 32,
                        color: CupertinoColors.white,
                      ),
                    ),
                  );
                },
              ),

              // Next
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => audioHandler.skipToNext(),
                child: const Icon(
                  CupertinoIcons.forward_fill,
                  size: 40,
                  color: CupertinoColors.white,
                ),
              ),

              // Repeat
              StreamBuilder<dynamic>(
                stream: audioHandler.repeatModeStream,
                builder: (context, snapshot) {
                  final repeatMode = snapshot.data;
                  IconData icon = CupertinoIcons.repeat;
                  bool isActive = false;
                  
                  if (repeatMode != null) {
                    final modeString = repeatMode.toString();
                    if (modeString.contains('one')) {
                      icon = CupertinoIcons.repeat_1;
                      isActive = true;
                    } else if (modeString.contains('all')) {
                      isActive = true;
                    }
                  }
                  
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => audioHandler.toggleRepeat(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.accentPink.withOpacity(0.2) : CupertinoColors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: isActive ? AppTheme.accentPink : CupertinoColors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),

        // Bottom bar with rounded container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Queue
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => setState(() => _showQueue = true),
                  child: Icon(
                    CupertinoIcons.list_bullet,
                    size: 22,
                    color: CupertinoColors.white.withOpacity(0.7),
                  ),
                ),

                // Favorite
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => appState.toggleFavorite(currentTrack),
                  child: Icon(
                    currentTrack.isFavorite
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    size: 22,
                    color: currentTrack.isFavorite
                        ? AppTheme.accentPink
                        : CupertinoColors.white.withOpacity(0.7),
                  ),
                ),

                // Lyrics
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () {},
                  child: Icon(
                    CupertinoIcons.text_quote,
                    size: 22,
                    color: CupertinoColors.white.withOpacity(0.7),
                  ),
                ),

                // More options
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _showTrackOptions(context, appState, currentTrack),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 22,
                    color: CupertinoColors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),
      ],
    );
  }

  Widget _buildQueueView(BuildContext context, AppState appState, Track currentTrack) {
    final audioHandler = appState.audioHandler!;
    final queue = audioHandler.queue;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showQueue = false),
                child: const Icon(
                  CupertinoIcons.chevron_down,
                  color: CupertinoColors.white,
                  size: 28,
                ),
              ),
              const Text(
                'Up Next',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle3,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Current track
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              children: [
                CachedArtwork(
                  imageUrl: currentTrack.imageUrl != null
                      ? appState.getImageUrl(currentTrack.imageUrl!, width: 120, height: 120)
                      : null,
                  size: 56,
                  borderRadius: AppTheme.radiusS,
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrack.name,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentTrack.artistName ?? '',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeFootnote,
                          color: CupertinoColors.white.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Queue list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final track = queue[index];
              final isCurrentTrack = track.id == currentTrack.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => audioHandler.skipToQueueItem(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentTrack
                          ? CupertinoColors.white.withOpacity(0.1)
                          : CupertinoColors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Row(
                      children: [
                        CachedArtwork(
                          imageUrl: track.imageUrl != null
                              ? appState.getImageUrl(track.imageUrl!, width: 80, height: 80)
                              : null,
                          size: 44,
                          borderRadius: AppTheme.radiusS,
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeFootnote,
                                  color: isCurrentTrack
                                      ? AppTheme.accentPink
                                      : CupertinoColors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                track.artistName ?? '',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeCaption,
                                  color: CupertinoColors.white.withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTrackOptions(BuildContext context, AppState appState, Track track) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
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
              // TODO: Implement add to playlist
            },
            child: const Text('Add to Playlist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to album
            },
            child: const Text('Go to Album'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to artist
            },
            child: const Text('Go to Artist'),
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
