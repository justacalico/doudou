import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/models/download_models.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/download_service.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';

class DownloadButton extends StatelessWidget {
  final Track track;
  final double size;
  final Color? color;

  const DownloadButton({
    super.key,
    required this.track,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        final status = downloadService.getDownloadStatus(track.id);
        final progress = downloadService.getDownloadProgress(track.id);

        return GestureDetector(
          onTap: () => _handleDownloadTap(context, downloadService, status),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getBackgroundColor(status),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(status), width: 1),
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: _buildIcon(status, progress),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(DownloadStatus status, double progress) {
    switch (status) {
      case DownloadStatus.notDownloaded:
        return Icon(
          CupertinoIcons.cloud_download,
          color: color ?? const Color(0xFF8E8E93),
          size: size,
        );

      case DownloadStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF007AFF),
                ),
                backgroundColor: const Color(0xFF333333),
              ),
            ),
            Icon(
              CupertinoIcons.pause,
              color: const Color(0xFF007AFF),
              size: size * 0.6,
            ),
          ],
        );

      case DownloadStatus.downloaded:
        return Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: const Color(0xFF00FF88),
          size: size,
        );

      case DownloadStatus.failed:
        return Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: const Color(0xFFFF453A),
          size: size,
        );

      case DownloadStatus.paused:
        return Icon(
          CupertinoIcons.pause_circle,
          color: const Color(0xFF8E8E93),
          size: size,
        );
    }
  }

  Color _getBackgroundColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF007AFF).withOpacity(0.1);
      case DownloadStatus.downloaded:
        return const Color(0xFF00FF88).withOpacity(0.1);
      case DownloadStatus.failed:
        return const Color(0xFFFF453A).withOpacity(0.1);
      default:
        return const Color(0xFF1C1C1E);
    }
  }

  Color _getBorderColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF007AFF).withOpacity(0.3);
      case DownloadStatus.downloaded:
        return const Color(0xFF00FF88).withOpacity(0.3);
      case DownloadStatus.failed:
        return const Color(0xFFFF453A).withOpacity(0.3);
      default:
        return const Color(0xFF2C2C2E);
    }
  }

  void _handleDownloadTap(
    BuildContext context,
    DownloadService downloadService,
    DownloadStatus status,
  ) {
    switch (status) {
      case DownloadStatus.notDownloaded:
        downloadService.downloadTrack(track);
        break;

      case DownloadStatus.downloading:
        _showDownloadOptions(context, downloadService);
        break;

      case DownloadStatus.downloaded:
        _showDownloadedOptions(context, downloadService);
        break;

      case DownloadStatus.failed:
        downloadService.downloadTrack(track); // Retry
        break;

      case DownloadStatus.paused:
        downloadService.downloadTrack(track); // Resume
        break;
    }
  }

  void _showDownloadOptions(
    BuildContext context,
    DownloadService downloadService,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(track.name),
        message: const Text('Download in progress'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Cancel Download'),
            onPressed: () {
              Navigator.pop(context);
              downloadService.cancelDownload(track.id);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showDownloadedOptions(
    BuildContext context,
    DownloadService downloadService,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(track.name),
        message: const Text('Downloaded for offline listening'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete Download'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteDownload(context, downloadService);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _confirmDeleteDownload(
    BuildContext context,
    DownloadService downloadService,
  ) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete Download',
      message: 'Delete "${track.name}" from your device?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (ok == true) {
      downloadService.deleteDownload(track.id);
    }
  }
}
