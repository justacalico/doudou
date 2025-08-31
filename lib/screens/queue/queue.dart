import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Queue',
          style: TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: Color(0xFF1C1C1E),
        border: null,
      ),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
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
                    color: CupertinoColors.systemGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No songs in queue',
                    style: TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                // Queue controls
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () {
                            if (isShuffled) {
                              audioHandler?.unshuffle();
                            } else {
                              audioHandler?.shuffle();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.shuffle,
                                color: isShuffled 
                                    ? const Color(0xFFFF453A) 
                                    : CupertinoColors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isShuffled ? 'Shuffled' : 'Shuffle',
                                style: TextStyle(
                                  color: isShuffled 
                                      ? const Color(0xFFFF453A) 
                                      : CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFF2C2C2E),
                          onPressed: () {
                            audioHandler?.clearQueue();
                            Navigator.pop(context);
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.clear, color: CupertinoColors.white),
                              SizedBox(width: 8),
                              Text('Clear Queue', style: TextStyle(color: CupertinoColors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Queue header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Playing from Queue',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${queueTracks.length} song${queueTracks.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Queue list
                Expanded(
                  child: ListView.builder(
                    itemCount: queueTracks.length,
                    itemBuilder: (context, index) {
                      final track = queueTracks[index];
                      final isCurrentTrack = index == currentIndex;
                      
                      return QueueTrackItem(
                        key: ValueKey(track.id),
                        track: track,
                        isCurrentTrack: isCurrentTrack,
                        canRemove: !isCurrentTrack,
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
            ),
          );
        },
      ),
    );
  }
}

class QueueTrackItem extends StatelessWidget {
  final Track track;
  final bool isCurrentTrack;
  final bool canRemove;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const QueueTrackItem({
    super.key,
    required this.track,
    required this.isCurrentTrack,
    required this.canRemove,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrentTrack 
            ? const Color(0xFF2C2C2E).withOpacity(0.8)
            : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentTrack 
            ? Border.all(color: const Color(0xFFFF453A), width: 1)
            : null,
      ),
      child: CupertinoListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            if (canRemove)
              const Icon(
                CupertinoIcons.line_horizontal_3,
                color: CupertinoColors.systemGrey,
                size: 16,
              ),
            const SizedBox(width: 8),
            // Album art
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF2C2C2E),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          track.imageUrl!,
                          width: 96,
                          height: 96,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_note,
                          color: CupertinoColors.systemGrey,
                          size: 24,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_note,
                        color: CupertinoColors.systemGrey,
                        size: 24,
                      ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            if (isCurrentTrack) ...[
              const Icon(
                CupertinoIcons.play_fill,
                color: Color(0xFFFF453A),
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
                      ? const Color(0xFFFF453A)
                      : CupertinoColors.white,
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
                style: const TextStyle(color: CupertinoColors.systemGrey),
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
                style: const TextStyle(color: CupertinoColors.systemGrey2),
              ),
            if (canRemove && onRemove != null) ...[
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onRemove,
                child: const Icon(
                  CupertinoIcons.minus_circle,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
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
