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
    final artworkSize = screenWidth - 80;

    return Column(
      children: [
        // Drag indicator pill (Apple Music style)
        const SizedBox(height: AppTheme.spacingS),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ),
        
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingXS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chevron down
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                onPressed: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: CupertinoColors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
              // Album name (or source)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Could navigate to album
                  },
                  child: Column(
                    children: [
                      Text(
                        currentTrack.albumName?.toUpperCase() ?? 'PLAYING FROM',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: CupertinoColors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // More options
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                onPressed: () => _showTrackOptions(context, appState, currentTrack),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

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

        const SizedBox(height: AppTheme.spacingXXL),

        // Track info with favorite button (Apple Music style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.name,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeTitle2,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        // Could navigate to artist
                      },
                      child: Text(
                        currentTrack.artistName ?? 'Unknown Artist',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeTitle3,
                          color: AppTheme.accentPink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              // Favorite button
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => appState.toggleFavorite(currentTrack),
                child: Icon(
                  currentTrack.isFavorite
                      ? CupertinoIcons.star_fill
                      : CupertinoIcons.star,
                  size: 26,
                  color: currentTrack.isFavorite
                      ? AppTheme.accentPink
                      : CupertinoColors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Progress bar
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
                  CupertinoSlider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      audioHandler.seek(newPosition);
                    },
                    activeColor: CupertinoColors.white,
                    thumbColor: CupertinoColors.white,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeCaption,
                            color: CupertinoColors.white.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeCaption,
                            color: CupertinoColors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: AppTheme.spacingL),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => audioHandler.toggleShuffle(),
                child: StreamBuilder<bool>(
                  stream: audioHandler.shuffleEnabledStream,
                  builder: (context, snapshot) {
                    final isShuffling = snapshot.data ?? false;
                    return Icon(
                      CupertinoIcons.shuffle,
                      size: 24,
                      color: isShuffling
                          ? AppTheme.accentPink
                          : CupertinoColors.white.withOpacity(0.6),
                    );
                  },
                ),
              ),

              // Previous
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => audioHandler.skipToPrevious(),
                child: const Icon(
                  CupertinoIcons.backward_fill,
                  size: 36,
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
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 36,
                        color: CupertinoColors.black,
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
                  size: 36,
                  color: CupertinoColors.white,
                ),
              ),

              // Repeat
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => audioHandler.toggleRepeat(),
                child: StreamBuilder<dynamic>(
                  stream: audioHandler.repeatModeStream,
                  builder: (context, snapshot) {
                    final repeatMode = snapshot.data;
                    IconData icon = CupertinoIcons.repeat;
                    Color color = CupertinoColors.white.withOpacity(0.6);
                    
                    if (repeatMode != null) {
                      final modeString = repeatMode.toString();
                      if (modeString.contains('one')) {
                        icon = CupertinoIcons.repeat_1;
                        color = AppTheme.accentPink;
                      } else if (modeString.contains('all')) {
                        color = AppTheme.accentPink;
                      }
                    }
                    
                    return Icon(icon, size: 24, color: color);
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingXL),

        // Bottom actions (Apple Music style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lyrics (placeholder)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: Icon(
                  CupertinoIcons.text_quote,
                  size: 22,
                  color: CupertinoColors.white.withOpacity(0.6),
                ),
              ),

              // AirPlay
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: Icon(
                  CupertinoIcons.antenna_radiowaves_left_right,
                  size: 22,
                  color: CupertinoColors.white.withOpacity(0.6),
                ),
              ),

              // Queue
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showQueue = true),
                child: Icon(
                  CupertinoIcons.list_bullet,
                  size: 22,
                  color: CupertinoColors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingM),

        // Volume slider (Apple Music style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.speaker_fill,
                size: 14,
                color: CupertinoColors.white.withOpacity(0.5),
              ),
              Expanded(
                child: CupertinoSlider(
                  value: 0.7,
                  onChanged: (value) {
                    // Volume control would go here
                  },
                  activeColor: CupertinoColors.white.withOpacity(0.6),
                  thumbColor: CupertinoColors.white,
                ),
              ),
              Icon(
                CupertinoIcons.speaker_3_fill,
                size: 14,
                color: CupertinoColors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),

        const Spacer(),
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
