import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/download_service.dart';
import 'playlists/playlists.dart';
import 'albums/albums.dart';
import 'songs/songs.dart';
import 'queue/queue.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          color: const Color(0xFF000000),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  color: Color(0xFF007AFF),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Downloads',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Offline music',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Settings button
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _showDownloadSettings(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF333333),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.gear,
                                    color: Color(0xFF8E8E93),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Tab selector
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            child: CupertinoSlidingSegmentedControl<int>(
                              groupValue: _tabController.index.clamp(0, 3),
                              onValueChanged: (value) {
                                if (value != null && value >= 0 && value < 4) {
                                  _tabController.animateTo(value);
                                  setState(() {});
                                }
                              },
                              children: const {
                                0: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Playlists'),
                                ),
                                1: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Albums'),
                                ),
                                2: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Songs'),
                                ),
                                3: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Queue'),
                                ),
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content based on selected tab
                  if (_tabController.index == 0)
                    const DownloadedPlaylistsTab()
                  else if (_tabController.index == 1)
                    const DownloadedAlbumsTab()
                  else if (_tabController.index == 2)
                    const DownloadedSongsTab()
                  else if (_tabController.index == 3)
                    const DownloadQueueTab()
                  else
                    const DownloadedPlaylistsTab(), // Default fallback
                  
                  // Bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadSettings(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const DownloadSettingsSheet(),
    );
  }
}

class DownloadSettingsSheet extends StatelessWidget {
  const DownloadSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E8E93),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Download Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
              
              // Settings options
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingsItem(
                      context,
                      'Clear All Downloads',
                      'Remove all downloaded music',
                      CupertinoIcons.trash,
                      const Color(0xFFFF453A),
                      () => _showClearAllDialog(context, downloadService),
                    ),
                    
                    _buildStorageInfo(downloadService),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF8E8E93),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageInfo(DownloadService downloadService) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Storage Usage',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: downloadService.getTotalDownloadedSize(),
            builder: (context, snapshot) {
              final totalSize = snapshot.data ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloaded: ${_formatFileSize(totalSize)}',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Songs: ${downloadService.downloadedTracks.length}',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, DownloadService downloadService) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Downloads'),
        content: const Text(
          'This will delete all downloaded music from your device. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear All'),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings sheet
              downloadService.clearAllDownloads();
            },
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

