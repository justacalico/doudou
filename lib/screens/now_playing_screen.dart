import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_state.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF2D2D2D), // Dark background like in the image
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          final audioService = appState.audioService;
          final currentTrack = audioService?.currentTrack;
          
          if (currentTrack == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.systemGrey),
                  SizedBox(height: 16),
                  Text(
                    'No music playing',
                    style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                // Top bar with chevron down and cast icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          CupertinoIcons.chevron_down,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Cast functionality placeholder
                        child: const Icon(
                          CupertinoIcons.antenna_radiowaves_left_right,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Album Art - large and centered
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: currentTrack.imageUrl != null
                        ? Image.network(
                            appState.jellyfinService.getImageUrl(
                              currentTrack.imageUrl!,
                              width: 800,
                              height: 800,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF4A4A4A),
                                child: const Icon(CupertinoIcons.music_albums, size: 120, color: CupertinoColors.systemGrey),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF4A4A4A),
                            child: const Icon(CupertinoIcons.music_albums, size: 120, color: CupertinoColors.systemGrey),
                          ),
                  ),
                ),
                
                const Spacer(),
                
                // Track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Text(
                        currentTrack.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (currentTrack.artistName != null)
                        Text(
                          currentTrack.artistName!,
                          style: const TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Progress slider
                StreamBuilder<Duration>(
                  stream: audioService?.positionStream ?? Stream.value(Duration.zero),
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = audioService?.duration ?? Duration.zero;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                              activeTrackColor: CupertinoColors.white,
                              inactiveTrackColor: CupertinoColors.systemGrey,
                              thumbColor: CupertinoColors.white,
                            ),
                            child: Slider(
                              value: duration.inMilliseconds > 0
                                  ? position.inMilliseconds / duration.inMilliseconds
                                  : 0.0,
                              onChanged: (value) {
                                final newPosition = Duration(
                                  milliseconds: (value * duration.inMilliseconds).round(),
                                );
                                appState.seekTo(newPosition);
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Control buttons
                StreamBuilder(
                  stream: audioService?.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = audioService?.isPlaying ?? false;
                    final processingState = audioService?.playerState.processingState;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {}, // Shuffle placeholder
                            child: const Icon(
                              CupertinoIcons.shuffle,
                              color: CupertinoColors.systemGrey,
                              size: 32,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: audioService?.hasPrevious == true
                                ? () => appState.skipToPrevious()
                                : null,
                            child: Icon(
                              CupertinoIcons.backward_fill,
                              size: 50,
                              color: audioService?.hasPrevious == true 
                                  ? CupertinoColors.white
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: processingState == ProcessingState.loading ||
                                    processingState == ProcessingState.buffering
                                ? const Center(
                                    child: CupertinoActivityIndicator(
                                      color: CupertinoColors.black,
                                    ),
                                  )
                                : CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      appState.playPause();
                                    },
                                    child: Icon(
                                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                                      size: 40,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: audioService?.hasNext == true
                                ? () => appState.skipToNext()
                                : null,
                            child: Icon(
                              CupertinoIcons.forward_fill,
                              size: 50,
                              color: audioService?.hasNext == true 
                                  ? CupertinoColors.white
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {}, // Repeat placeholder
                            child: const Icon(
                              CupertinoIcons.repeat,
                              color: CupertinoColors.systemGrey,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Queue/playlist
                        child: const Icon(
                          CupertinoIcons.list_bullet,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Heart/like
                        child: const Icon(
                          CupertinoIcons.heart,
                          color: CupertinoColors.systemRed,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Share/more
                        child: const Icon(
                          CupertinoIcons.square_arrow_up,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // More options
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          );
        },
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
