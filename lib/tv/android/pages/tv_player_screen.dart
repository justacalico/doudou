import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../../providers/app_state.dart';
import '../widgets/tv_focus_border.dart';

/// Android TV Player Screen
/// 
/// Full-screen now playing interface optimized for TV with D-pad controls
class TVPlayerScreen extends StatefulWidget {
  const TVPlayerScreen({super.key});

  @override
  State<TVPlayerScreen> createState() => _TVPlayerScreenState();
}

class _TVPlayerScreenState extends State<TVPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return StreamBuilder<MediaItem?>(
            stream: appState.mediaItem,
            builder: (context, snapshot) {
              final mediaItem = snapshot.data;
              
              if (mediaItem == null) {
                return _buildNoTrackView();
              }

              return Stack(
                children: [
                  // Background with album art
                  _buildBackground(mediaItem),
                  
                  // Main content
                  SafeArea(
                    child: Column(
                      children: [
                        // Header with back button
                        _buildHeader(context),
                        
                        const Spacer(),
                        
                        // Album art and track info
                        _buildTrackInfo(mediaItem),
                        
                        const Spacer(),
                        
                        // Player controls
                        _buildControls(appState),
                        
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground(MediaItem mediaItem) {
    return Container(
      decoration: BoxDecoration(
        image: mediaItem.artUri != null
            ? DecorationImage(
                image: NetworkImage(mediaItem.artUri.toString()),
                fit: BoxFit.cover,
                opacity: 0.15,
              )
            : null,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.shade900.withOpacity(0.5),
            Colors.black,
            Colors.black,
          ],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          TVFocusBorder(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 36),
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Spacer(),
          const Text(
            'Now Playing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildTrackInfo(MediaItem mediaItem) {
    return Column(
      children: [
        // Album art
        Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.5),
                blurRadius: 50,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: mediaItem.artUri != null
                ? Image.network(
                    mediaItem.artUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildAlbumPlaceholder(),
                  )
                : _buildAlbumPlaceholder(),
          ),
        ),
        
        const SizedBox(height: 48),
        
        // Track title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100),
          child: Text(
            mediaItem.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Artist name
        if (mediaItem.artist != null)
          Text(
            mediaItem.artist!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 28,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
          ),
        
        const SizedBox(height: 12),
        
        // Album name
        if (mediaItem.album != null)
          Text(
            mediaItem.album!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildAlbumPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.album,
          size: 120,
          color: Colors.white24,
        ),
      ),
    );
  }

  Widget _buildControls(AppState appState) {
    return StreamBuilder<PlaybackState>(
      stream: appState.playbackState,
      builder: (context, stateSnapshot) {
        final playbackState = stateSnapshot.data;
        final isPlaying = playbackState?.playing ?? false;
        final position = playbackState?.position ?? Duration.zero;

        return StreamBuilder<MediaItem?>(
          stream: appState.mediaItem,
          builder: (context, mediaSnapshot) {
            final duration = mediaSnapshot.data?.duration ?? Duration.zero;

            return Column(
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purple,
                          inactiveTrackColor: Colors.grey.shade800,
                          thumbColor: Colors.white,
                          overlayColor: Colors.purple.withOpacity(0.3),
                          trackHeight: 8.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12.0,
                          ),
                        ),
                        child: TVFocusBorder(
                          child: Slider(
                            value: position.inMilliseconds.toDouble(),
                            max: duration.inMilliseconds.toDouble() > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (value) {
                              appState.audioHandler?.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous button
                    _buildControlButton(
                      icon: Icons.skip_previous,
                      size: 60,
                      onPressed: () => appState.audioHandler?.skipToPrevious(),
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Seek backward
                    _buildControlButton(
                      icon: Icons.replay_10,
                      size: 60,
                      onPressed: () {
                        final newPosition = position - const Duration(seconds: 10);
                        appState.audioHandler?.seek(
                          newPosition.isNegative ? Duration.zero : newPosition,
                        );
                      },
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Play/Pause button
                    _buildControlButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 100,
                      isPrimary: true,
                      onPressed: () {
                        if (isPlaying) {
                          appState.audioHandler?.pause();
                        } else {
                          appState.audioHandler?.play();
                        }
                      },
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Seek forward
                    _buildControlButton(
                      icon: Icons.forward_30,
                      size: 60,
                      onPressed: () {
                        final newPosition = position + const Duration(seconds: 30);
                        if (newPosition < duration) {
                          appState.audioHandler?.seek(newPosition);
                        }
                      },
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Next button
                    _buildControlButton(
                      icon: Icons.skip_next,
                      size: 60,
                      onPressed: () => appState.audioHandler?.skipToNext(),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return TVFocusBorder(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isPrimary
              ? LinearGradient(
                  colors: [Colors.purple.shade700, Colors.purple.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : Colors.grey.shade900,
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? Colors.purple.withOpacity(0.5)
                  : Colors.black.withOpacity(0.5),
              blurRadius: isPrimary ? 30 : 15,
              spreadRadius: isPrimary ? 5 : 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoTrackView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_off,
            size: 120,
            color: Colors.white24,
          ),
          const SizedBox(height: 32),
          const Text(
            'No track playing',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 48),
          TVFocusBorder(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                textStyle: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
