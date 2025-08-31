import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/app_state.dart';
import '../queue/queue.dart';

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
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
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
                      
                      const SizedBox(height: 20),
                      
                      // Album Art - responsive size
                      Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        height: MediaQuery.of(context).size.width * 0.75,
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                          maxHeight: 320,
                        ),
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
                                      child: const Icon(CupertinoIcons.music_albums, size: 80, color: CupertinoColors.systemGrey),
                                    );
                                  },
                                )
                              : Container(
                                  color: const Color(0xFF4A4A4A),
                                  child: const Icon(CupertinoIcons.music_albums, size: 80, color: CupertinoColors.systemGrey),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Track info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          children: [
                            Text(
                              currentTrack.name,
                              style: const TextStyle(
                                fontSize: 24,
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
                                  fontSize: 16,
                                  color: CupertinoColors.systemGrey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
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
                                CupertinoSlider(
                                  value: duration.inMilliseconds > 0
                                      ? position.inMilliseconds / duration.inMilliseconds
                                      : 0.0,
                                  onChanged: (value) {
                                    final newPosition = Duration(
                                      milliseconds: (value * duration.inMilliseconds).round(),
                                    );
                                    appState.seekTo(newPosition);
                                  },
                                  activeColor: CupertinoColors.white,
                                  thumbColor: CupertinoColors.white,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Control buttons
                      StreamBuilder(
                        stream: audioService?.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = audioService?.isPlaying ?? false;
                          final processingState = audioService?.playerState.processingState;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final audioService = appState.audioService;
                                    if (audioService?.isShuffled == true) {
                                      audioService?.unshuffle();
                                    } else {
                                      audioService?.shuffle();
                                    }
                                  },
                                  child: Icon(
                                    CupertinoIcons.shuffle,
                                    color: audioService?.isShuffled == true 
                                        ? const Color(0xFFFF453A)
                                        : CupertinoColors.systemGrey,
                                    size: 28,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioService?.hasPrevious == true
                                      ? () => appState.skipToPrevious()
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.backward_fill,
                                    size: 40,
                                    color: audioService?.hasPrevious == true 
                                        ? CupertinoColors.white
                                        : CupertinoColors.systemGrey,
                                  ),
                                ),
                                Container(
                                  width: 70,
                                  height: 70,
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
                                            size: 35,
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
                                    size: 40,
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
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Bottom controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const QueueScreen(),
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.list_bullet,
                                color: CupertinoColors.white,
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                appState.toggleFavorite(currentTrack);
                              },
                              child: Icon(
                                currentTrack.isFavorite 
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: currentTrack.isFavorite 
                                    ? const Color(0xFFFF453A)
                                    : CupertinoColors.systemRed,
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {}, // Share/more
                              child: const Icon(
                                CupertinoIcons.square_arrow_up,
                                color: CupertinoColors.white,
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {}, // More options
                              child: const Icon(
                                CupertinoIcons.ellipsis,
                                color: CupertinoColors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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
