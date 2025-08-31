import 'package:flutter/cupertino.dart';
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Now Playing'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          final audioService = appState.audioService;
          final currentTrack = audioService?.currentTrack;
          
          if (currentTrack == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.secondaryLabel),
                  SizedBox(height: 16),
                  Text(
                    'No music playing',
                    style: TextStyle(fontSize: 18, color: CupertinoColors.secondaryLabel),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // Album Art
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: currentTrack.imageUrl != null
                        ? Image.network(
                            appState.jellyfinService.getImageUrl(
                              currentTrack.imageUrl!,
                              width: 600,
                              height: 600,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: CupertinoColors.systemGrey4.resolveFrom(context),
                                child: const Icon(CupertinoIcons.music_albums, size: 120),
                              );
                            },
                          )
                        : Container(
                            color: CupertinoColors.systemGrey4.resolveFrom(context),
                            child: const Icon(CupertinoIcons.music_albums, size: 120),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Track info
                Text(
                  currentTrack.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (currentTrack.artistName != null)
                  Text(
                    currentTrack.artistName!,
                    style: TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                if (currentTrack.albumName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    currentTrack.albumName!,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // Progress slider
                StreamBuilder<Duration>(
                  stream: audioService?.positionStream ?? Stream.value(Duration.zero),
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = audioService?.duration ?? Duration.zero;
                    
                    return Column(
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
                          activeColor: CupertinoColors.systemPurple,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ),
                      ],
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
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CupertinoButton(
                          onPressed: audioService?.hasPrevious == true
                              ? () => appState.skipToPrevious()
                              : null,
                          child: Icon(
                            CupertinoIcons.backward_fill,
                            size: 40,
                            color: audioService?.hasPrevious == true 
                                ? CupertinoColors.label.resolveFrom(context)
                                : CupertinoColors.quaternaryLabel.resolveFrom(context),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemPurple.resolveFrom(context),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: processingState == ProcessingState.loading ||
                                  processingState == ProcessingState.buffering
                              ? const Center(
                                  child: CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  ),
                                )
                              : CupertinoButton(
                                  onPressed: () {
                                    appState.playPause();
                                  },
                                  child: Icon(
                                    isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                                    size: 40,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                        ),
                        CupertinoButton(
                          onPressed: audioService?.hasNext == true
                              ? () => appState.skipToNext()
                              : null,
                          child: Icon(
                            CupertinoIcons.forward_fill,
                            size: 40,
                            color: audioService?.hasNext == true 
                                ? CupertinoColors.label.resolveFrom(context)
                                : CupertinoColors.quaternaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const Spacer(),
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
