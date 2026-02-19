import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/lyrics_service.dart';
import '../theme.dart';
import '../widgets/source_pill.dart';
import '../widgets/track_tile.dart';
import '../widgets/universal_image.dart';

/// Full now playing: three swipeable pages (Now Playing, Lyrics, Queue). Minimal page indicator.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  LyricsResult? _lyricsResult;
  bool _lyricsLoading = false;
  String? _lastTrackKey;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadLyrics(String title, String artist) async {
    final key = '$title|$artist';
    if (_lastTrackKey == key) return;
    _lastTrackKey = key;
    setState(() {
      _lyricsLoading = true;
      _lyricsResult = null;
    });
    final result = await LyricsService.fetchLyrics(title, artist);
    if (mounted && _lastTrackKey == key) {
      setState(() {
        _lyricsResult = result;
        _lyricsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    color: AppTheme.textPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _PageIndicator(
                    currentPage: _currentPage,
                    pageCount: 3,
                    onPageTap: (i) {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _NowPlayingPage(accent: accent, onLyricsRequest: _loadLyrics),
                  _LyricsPage(
                    lyricsResult: _lyricsResult,
                    isLoading: _lyricsLoading,
                    accent: accent,
                  ),
                  const _QueuePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageTap;

  const _PageIndicator({
    required this.currentPage,
    required this.pageCount,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (i) {
        final selected = i == currentPage;
        return GestureDetector(
          onTap: () => onPageTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: selected ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
        );
      }),
    );
  }
}

class _NowPlayingPage extends StatelessWidget {
  final Color accent;
  final void Function(String title, String artist) onLyricsRequest;

  const _NowPlayingPage({required this.accent, required this.onLyricsRequest});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final handler = appState.audioHandler;
        if (handler == null) {
          return const Center(child: Text('Nothing playing', style: TextStyle(color: AppTheme.textSecondary)));
        }
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, snap) {
            final mediaItem = snap.data;
            if (mediaItem == null) {
              return const Center(child: Text('Nothing playing', style: TextStyle(color: AppTheme.textSecondary)));
            }
            final imageUrl = mediaItem.artUri?.toString() ?? mediaItem.extras?['localImageUrl'] as String?;
            return StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
                    builder: (context, playSnap) {
                final playState = playSnap.data;
                final playing = playState?.playing ?? false;
                final repeatMode = playState?.repeatMode ?? AudioServiceRepeatMode.none;
                return StreamBuilder<Duration>(
                  stream: handler.positionStream,
                  builder: (context, posSnap) {
                    final position = posSnap.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: handler.durationStream,
                      builder: (context, durSnap) {
                        final duration = durSnap.data ?? Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onLyricsRequest(mediaItem.title, mediaItem.artist ?? '');
                        });
                        final serverType = appState.mediaServiceManager.currentServerType;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                  child: UniversalImage(
                                    imageUrl: imageUrl,
                                    width: 280,
                                    height: 280,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                mediaItem.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mediaItem.artist ?? 'Unknown Artist',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (mediaItem.album != null && mediaItem.album!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  mediaItem.album!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              SourcePill(source: serverType),
                              const SizedBox(height: 24),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: accent,
                                  inactiveTrackColor: AppTheme.surfaceElevated,
                                  thumbColor: accent,
                                  overlayColor: accent.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: progress.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    final ms = (v * duration.inMilliseconds).round();
                                    handler.seek(Duration(milliseconds: ms));
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      playState?.shuffleMode == AudioServiceShuffleMode.all
                                          ? Icons.shuffle_rounded
                                          : Icons.shuffle_outlined,
                                      color: playState?.shuffleMode == AudioServiceShuffleMode.all
                                          ? accent
                                          : AppTheme.textSecondary,
                                    ),
                                    onPressed: () {
                                      handler.setShuffleMode(
                                        playState?.shuffleMode != AudioServiceShuffleMode.all,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, size: 36),
                                    onPressed: handler.hasPrevious == true ? appState.skipToPrevious : null,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 56,
                                      color: accent,
                                    ),
                                    onPressed: () => appState.playPause(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, size: 36),
                                    onPressed: handler.hasNext == true ? appState.skipToNext : null,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _repeatIcon(repeatMode),
                                      color: repeatMode != AudioServiceRepeatMode.none
                                          ? accent
                                          : AppTheme.textSecondary,
                                    ),
                                    onPressed: () {
                                      final next = repeatMode == AudioServiceRepeatMode.none
                                          ? AudioServiceRepeatMode.all
                                          : repeatMode == AudioServiceRepeatMode.all
                                              ? AudioServiceRepeatMode.one
                                              : AudioServiceRepeatMode.none;
                                      handler.setRepeatMode(next);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  IconData _repeatIcon(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return Icons.repeat_one_rounded;
      case AudioServiceRepeatMode.all:
        return Icons.repeat_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }
}

class _LyricsPage extends StatelessWidget {
  final LyricsResult? lyricsResult;
  final bool isLoading;
  final Color accent;

  const _LyricsPage({
    this.lyricsResult,
    required this.isLoading,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (lyricsResult == null || (lyricsResult!.syncedLyrics == null || lyricsResult!.syncedLyrics!.isEmpty)) {
      return const Center(
        child: Text(
          'No lyrics available',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
        ),
      );
    }
    final lines = lyricsResult!.syncedLyrics!;
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return StreamBuilder<Duration>(
          stream: appState.audioHandler?.positionStream,
          builder: (context, snap) {
            final position = snap.data ?? Duration.zero;
            int currentIndex = -1;
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].timestamp <= position) currentIndex = i;
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final line = lines[i];
                final isPast = i < currentIndex;
                final isCurrent = i == currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: isCurrent ? 20 : 16,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      color: isCurrent
                          ? accent
                          : isPast
                              ? AppTheme.textTertiary
                              : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QueuePage extends StatelessWidget {
  const _QueuePage();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final queue = appState.queue;
        final currentTrack = appState.audioHandler?.currentTrack;
        if (queue.isEmpty) {
          return const Center(
            child: Text(
              'Queue is empty',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: queue.length,
          itemBuilder: (context, i) {
            final track = queue[i];
            final isCurrent = currentTrack?.id == track.id;
            return TrackTile(
              track: track,
              index: i,
              playlist: queue,
              showTrackNumber: true,
              showArtwork: true,
              isCurrentTrack: isCurrent,
            );
          },
        );
      },
    );
  }
}
