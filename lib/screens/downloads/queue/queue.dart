import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../models/download_models.dart';
import '../../../models/jellyfin_models.dart';
import '../../../services/download_service.dart';

class DownloadQueueTab extends StatelessWidget {
  const DownloadQueueTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return _buildDownloadQueue(downloadService, appState);
      },
    );
  }

  Widget _buildDownloadQueue(DownloadService downloadService, AppState appState) {
    final downloadTasks = downloadService.downloadTasks;
    
    if (downloadTasks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloads in queue',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Add songs to download queue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Count tasks that can be retried (failed or paused)
    final retryableTasks = downloadTasks.where((task) => 
      task.status == DownloadStatus.failed || task.status == DownloadStatus.paused
    ).toList();
    final showRetryAll = retryableTasks.length >= 2;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Show retry all button as first item if needed
          if (index == 0 && showRetryAll) {
            return _buildRetryAllButton(downloadService, appState, retryableTasks);
          }
          
          // Adjust index for download tasks if retry all button is shown
          final taskIndex = showRetryAll ? index - 1 : index;
          if (taskIndex < 0 || taskIndex >= downloadTasks.length) {
            return const SizedBox.shrink();
          }
          
          final task = downloadTasks[taskIndex];
          return DownloadTaskItem(
            task: task,
            onCancel: () => downloadService.cancelDownload(task.trackId),
            onRetry: () => _retryDownload(downloadService, task, appState),
          );
        },
        childCount: downloadTasks.length + (showRetryAll ? 1 : 0),
      ),
    );
  }

  Widget _buildRetryAllButton(DownloadService downloadService, AppState appState, List<DownloadTask> retryableTasks) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _retryAllDownloads(downloadService, appState, retryableTasks),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0056CC),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.refresh,
                color: Color(0xFFFFFFFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Retry All (${retryableTasks.length})',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retryAllDownloads(DownloadService downloadService, AppState appState, List<DownloadTask> retryableTasks) {
    if (kDebugMode) {
      print('_retryAllDownloads called for ${retryableTasks.length} tasks');
    }
    
    for (final task in retryableTasks) {
      _retryDownload(downloadService, task, appState);
    }
  }

  void _retryDownload(DownloadService downloadService, DownloadTask task, AppState appState) {
    if (kDebugMode) {
      print('_retryDownload called for task: ${task.trackName}, status: ${task.status}');
    }
    
    // Find the track and retry download
    final track = appState.tracks.firstWhere(
      (t) => t.id == task.trackId,
      orElse: () => Track(
        id: task.trackId,
        name: task.trackName,
        artistName: task.artistName,
        albumName: task.albumName,
        imageUrl: task.imageUrl,
      ),
    );
    
    if (kDebugMode) {
      print('Retrying download for track: ${track.name}');
    }
    
    downloadService.downloadTrack(track);
  }
}

class DownloadTaskItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const DownloadTaskItem({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF1C1C1E),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                  width: 1,
                ),
              ),
              child: Center(
                child: _buildStatusIcon(),
              ),
            ),
            const SizedBox(width: 16),
            
            // Track info and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.trackName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                      fontSize: 16,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.artistName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.artistName!,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  
                  // Progress bar and status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: task.progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(task.progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action button
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused) ? onRetry : onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: Icon(
                  (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused)
                      ? CupertinoIcons.refresh
                      : CupertinoIcons.xmark,
                  color: (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused)
                      ? const Color(0xFF007AFF)
                      : const Color(0xFF8E8E93),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return const CupertinoActivityIndicator(
          color: Color(0xFF007AFF),
        );
      case DownloadStatus.failed:
        return const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: Color(0xFFFF453A),
          size: 24,
        );
      case DownloadStatus.paused:
        return const Icon(
          CupertinoIcons.pause,
          color: Color(0xFF8E8E93),
          size: 24,
        );
      default:
        return const Icon(
          CupertinoIcons.clock,
          color: Color(0xFF8E8E93),
          size: 24,
        );
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return const Color(0xFF007AFF);
      case DownloadStatus.failed:
        return const Color(0xFFFF453A);
      case DownloadStatus.paused:
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.downloading:
        if (task.totalBytes != null && task.downloadedBytes != null) {
          return '${_formatFileSize(task.downloadedBytes!)} / ${_formatFileSize(task.totalBytes!)}';
        }
        return 'Downloading...';
      case DownloadStatus.failed:
        return task.errorMessage ?? 'Download failed';
      case DownloadStatus.paused:
        return 'Cancelled - Tap to retry';
      default:
        return 'Waiting...';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
