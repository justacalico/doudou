import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_state.dart';
import '../models/jellyfin_models.dart';

/// Shows the queue overlay with glass-morphism design
void showQueueOverlay(BuildContext context) {
  showCupertinoModalPopup(
    context: context,
    barrierColor: Colors.black.withOpacity(0.3),
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
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Queue',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Playing from queue',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
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
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      color: Colors.white,
                                      size: 18,
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
        );
      },
    );
  }

  Widget _buildQueueContent(AppState appState) {
    final audioHandler = appState.audioHandler;
    final queueTracks = audioHandler?.queueTracks ?? [];
    final currentIndex = audioHandler?.currentIndex ?? 0;
    final isShuffled = audioHandler?.isShuffled ?? false;

    if (queueTracks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.list_bullet,
              size: 64,
              color: Colors.white38,
            ),
            SizedBox(height: 16),
            Text(
              'No songs in queue',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Queue controls
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: CupertinoIcons.shuffle,
                  label: isShuffled ? 'Shuffled' : 'Shuffle',
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
                  label: 'Clear Queue',
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
        
        // Queue header info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                '${queueTracks.length} song${queueTracks.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isShuffled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'SHUFFLED',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Queue list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: queueTracks.length,
            itemBuilder: (context, index) {
              final track = queueTracks[index];
              final isCurrentTrack = index == currentIndex;
              
              return _buildQueueItem(
                track: track,
                isCurrentTrack: isCurrentTrack,
                appState: appState,
                onTap: () {
                  if (!isCurrentTrack) {
                    appState.skipToIndex(index);
                  }
                },
                onRemove: isCurrentTrack ? null : () {
                  audioHandler?.removeFromQueue(index);
                },
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: isActive 
          ? Colors.red.withOpacity(0.2)
          : Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.red : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.red : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          border: isCurrentTrack
              ? Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 2,
                )
              : null,
        ),
        child: CupertinoListTile(
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: appState.jellyfinService.getImageUrl(
                        track.imageUrl!,
                        width: 96,
                        height: 96,
                      ),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CupertinoActivityIndicator(
                          color: Colors.white38,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
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
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  track.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCurrentTrack ? Colors.red : Colors.white,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: track.artistName != null
              ? Text(
                  track.artistName!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.duration != null)
                Text(
                  _formatDuration(Duration(milliseconds: track.duration!)),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              if (onRemove != null && !isCurrentTrack) ...[
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 24,
                  onPressed: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.minus,
                      color: Colors.red,
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
