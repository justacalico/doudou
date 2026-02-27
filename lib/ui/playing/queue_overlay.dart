import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/ui/widgets/cached_image_widget.dart';

/// Shows the queue overlay with glass-morphism design
void showQueueOverlay(BuildContext context) {
  showCupertinoModalPopup(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) => const QueueOverlay(),
  );
}

class QueueOverlay extends StatefulWidget {
  const QueueOverlay({super.key});

  @override
  State<QueueOverlay> createState() => _QueueOverlayState();
}

class _QueueOverlayState extends State<QueueOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = math.min(740.0, screenSize.width - 24);
    final panelHeight = math.min(screenSize.height * 0.84, 860.0);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: panelWidth,
                  height: panelHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF050C19).withValues(alpha: 0.68),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 42,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF102544).withValues(alpha: 0.42),
                              const Color(0xFF071021).withValues(alpha: 0.26),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                18,
                                14,
                                14,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context).queue,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 38,
                                            height: 1.0,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppLocalizations.of(context)
                                              .playingFromQueue,
                                          style: const TextStyle(
                                            color: Color(0xFFB7C3D8),
                                            fontSize: 17,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _animationController.reverse().then((_) {
                                        Navigator.of(context).pop();
                                      });
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.xmark,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Queue content
                            Expanded(
                              child: Consumer<AppState>(
                                builder: (context, appState, child) {
                                  return _buildQueueContent(appState);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueContent(AppState appState) {
    final audioHandler = appState.audioHandler;
    final queueTracks = audioHandler?.queueTracks ?? [];
    final rawCurrentIndex = audioHandler?.currentIndex ?? 0;
    final currentIndex =
        rawCurrentIndex >= 0 && rawCurrentIndex < queueTracks.length
        ? rawCurrentIndex
        : 0;
    final displayIndices = List<int>.generate(
      queueTracks.length,
      (i) => i,
    ).where((i) => i != currentIndex).toList();
    final isShuffled = audioHandler?.isShuffled ?? false;

    if (queueTracks.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.list_bullet,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSongsInQueue,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Queue controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: CupertinoIcons.shuffle,
                  label: isShuffled ? l10n.shuffled : l10n.shuffle,
                  isActive: isShuffled,
                  onPressed: () {
                    if (isShuffled) {
                      audioHandler?.unshuffle();
                    } else {
                      audioHandler?.shuffle();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton(
                  icon: CupertinoIcons.clear,
                  label: l10n.clearQueue,
                  isActive: false,
                  onPressed: () {
                    audioHandler?.clearQueue();
                    _animationController.reverse().then((_) {
                      Navigator.of(context).pop();
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Current track card (always pinned)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: _buildCurrentTrackCard(
            track: queueTracks[currentIndex],
            appState: appState,
          ),
        ),

        // Queue header info
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                l10n.countSongs(queueTracks.length),
                style: const TextStyle(
                  color: Color(0xFFD5DFEF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              if (isShuffled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF4D6D).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    l10n.shuffled,
                    style: const TextStyle(
                      color: Color(0xFFFF8DA6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Queue list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            itemCount: displayIndices.length,
            itemBuilder: (context, index) {
              final queueIndex = displayIndices[index];
              final track = queueTracks[queueIndex];
              final isCurrentTrack = queueIndex == currentIndex;

              return KeyedSubtree(
                key: ValueKey('${track.id}-$queueIndex'),
                child: _buildQueueItem(
                  track: track,
                  isCurrentTrack: isCurrentTrack,
                  appState: appState,
                  onTap: () {
                    if (!isCurrentTrack) {
                      appState.skipToIndex(queueIndex);
                    }
                  },
                  onRemove: isCurrentTrack
                      ? null
                      : () {
                          audioHandler?.removeFromQueue(queueIndex);
                        },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      color: isActive
          ? const Color(0xFFFF4D6D).withValues(alpha: 0.26)
          : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFFF8DA6) : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFFA5B8) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTrackCard({
    required Track track,
    required AppState appState,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFF4D6D).withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFFFF5E7D).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: track.imageUrl != null
                ? CachedImageWidget(
                    imageUrl: appState.getImageUrl(
                      track.imageUrl!,
                      width: 100,
                      height: 100,
                    ),
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    placeholder: const CupertinoActivityIndicator(
                      color: Colors.white38,
                    ),
                    errorWidget: const Icon(
                      CupertinoIcons.music_note,
                      color: Colors.white54,
                    ),
                  )
                : Container(
                    width: 46,
                    height: 46,
                    color: Colors.white.withValues(alpha: 0.08),
                    child: const Icon(
                      CupertinoIcons.music_note,
                      color: Colors.white54,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          const Icon(
            CupertinoIcons.play_fill,
            size: 16,
            color: Color(0xFFFF6F8B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF9AB0),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName ?? AppLocalizations.of(context).unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC9D4E8),
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (track.duration != null)
            Text(
              _formatDuration(Duration(milliseconds: track.duration!)),
              style: const TextStyle(
                color: Color(0xFFE7EAF2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueItem({
    required Track track,
    required bool isCurrentTrack,
    required AppState appState,
    required VoidCallback onTap,
    required VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCurrentTrack
              ? const Color(0xFFFF4D6D).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          border: isCurrentTrack
              ? Border.all(
                  color: const Color(0xFFFF5E7D).withValues(alpha: 0.55),
                )
              : Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: CupertinoListTile(
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.imageUrl != null
                  ? CachedImageWidget(
                      imageUrl: appState.getImageUrl(
                        track.imageUrl!,
                        width: 96,
                        height: 96,
                      ),
                      fit: BoxFit.cover,
                      placeholder: const Center(
                        child: CupertinoActivityIndicator(
                          color: Colors.white38,
                        ),
                      ),
                      errorWidget: const Icon(
                        CupertinoIcons.music_note,
                        color: Colors.white38,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.music_note,
                      color: Colors.white38,
                      size: 24,
                    ),
            ),
          ),
          title: Row(
            children: [
              if (isCurrentTrack) ...[
                const Icon(
                  CupertinoIcons.play_fill,
                  color: Color(0xFFFF6F8B),
                  size: 16,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  track.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCurrentTrack
                        ? const Color(0xFFFF8DA6)
                        : const Color(0xFFE7EDF9),
                    fontSize: 15,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            track.artistName ?? AppLocalizations.of(context).unknownArtist,
            style: const TextStyle(
              color: Color(0xFF9DACCA),
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.duration != null)
                Text(
                  _formatDuration(Duration(milliseconds: track.duration!)),
                  style: const TextStyle(
                    color: Color(0xFFB8C4DA),
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              if (onRemove != null && !isCurrentTrack) ...[
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  onPressed: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.minus,
                      color: Color(0xFFFF8DA6),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
