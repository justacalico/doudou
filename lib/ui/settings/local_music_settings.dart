import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/apple_design/liquid_glass.dart';
import 'package:doudou/services/players/local_music_service.dart';

class LocalMusicSettingsScreen extends StatefulWidget {
  final bool isInitialSetup;

  const LocalMusicSettingsScreen({super.key, this.isInitialSetup = false});

  @override
  State<LocalMusicSettingsScreen> createState() =>
      _LocalMusicSettingsScreenState();
}

class _LocalMusicSettingsScreenState extends State<LocalMusicSettingsScreen> {
  bool _isScanning = false;
  int _scannedFiles = 0;
  int _totalFiles = 0;
  String? _errorMessage;

  LocalMusicService? get _localService {
    final appState = context.read<AppState>();
    return appState.mediaServiceManager.localMusicService;
  }

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    final appState = context.read<AppState>();

    // Ensure the local music service is created
    var service = appState.mediaServiceManager.localMusicService;
    if (service == null) {
      // Create the service by adding a dummy call that initializes it
      await appState.mediaServiceManager.setLocalMusicService();
      service = appState.mediaServiceManager.localMusicService;
    }

    if (service != null && !service.isInitialized) {
      await service.initialize();
    }

    if (mounted) setState(() {});
  }

  Future<bool> _requestStoragePermission() async {
    // Only need permissions on Android
    if (!Platform.isAndroid) return true;

    // Check Android version for appropriate permission
    PermissionStatus status;

    // For Android 13+ (API 33), use audio permission
    // For older versions, use storage permission
    if (await Permission.audio.status.isDenied) {
      status = await Permission.audio.request();
      if (status.isGranted) return true;
    }

    // Try storage permission as fallback for older Android
    if (await Permission.storage.status.isDenied) {
      status = await Permission.storage.request();
      if (status.isGranted) return true;
    }

    // Check if already granted
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }

    // If permanently denied, show settings dialog
    if (await Permission.audio.isPermanentlyDenied ||
        await Permission.storage.isPermanentlyDenied) {
      if (mounted) {
        final shouldOpenSettings = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Storage permission is required to access your music files. '
              'Please enable it in app settings.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }

    return false;
  }

  Future<void> _addDirectory() async {
    try {
      // Request storage permission on Android first
      if (Platform.isAndroid) {
        final hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Storage permission is required to access music folders';
            });
          }
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder',
        lockParentWindow: true,
      );

      if (selectedDirectory != null && mounted) {
        final appState = context.read<AppState>();
        await appState.mediaServiceManager.addLocalMusicDirectory(
          selectedDirectory,
        );
        setState(() {});

        // Show success dialog
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Folder Added'),
              content: Text('Added: ${selectedDirectory.split('/').last}'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to add directory: $e';
        });
      }
    }
  }

  Future<void> _removeDirectory(String dirPath) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove Directory?'),
        content: Text('Remove "$dirPath" from your music sources?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final appState = context.read<AppState>();
      await appState.mediaServiceManager.removeLocalMusicDirectory(dirPath);
      setState(() {});
    }
  }

  Future<void> _scanDirectories() async {
    if (_isScanning) return;

    final service = _localService;
    if (service == null || service.musicDirectories.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one music directory first';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _scannedFiles = 0;
      _totalFiles = 0;
      _errorMessage = null;
    });

    try {
      final appState = context.read<AppState>();
      await appState.mediaServiceManager.scanLocalMusicDirectories(
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _scannedFiles = processed;
              _totalFiles = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isScanning = false;
        });

        // Show completion message
        final trackCount = service.isInitialized
            ? (await service.getTracks()).length
            : 0;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scan complete! Found $trackCount tracks'),
              backgroundColor: AppleColors.systemGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _continueToApp() async {
    final service = _localService;
    if (service == null) {
      setState(() {
        _errorMessage =
            'Local music service not initialized. Please try again.';
      });
      return;
    }

    final tracks = await service.getTracks();

    if (tracks.isEmpty) {
      setState(() {
        _errorMessage =
            'No music found. Please add directories and scan for music.';
      });
      return;
    }

    if (!mounted) return;

    final appState = context.read<AppState>();

    final success = await appState.loginWithLocalMusic();

    if (success && mounted) {
      // Pop back to login screen, which will then show home since isLoggedIn is true
      // Use canPop check since the widget tree may already be rebuilding
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else if (!success && mounted) {
      setState(() {
        _errorMessage = 'Failed to initialize local music mode';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final service = _localService;
    final directories = service?.musicDirectories ?? [];

    return LiquidGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.isInitialSetup)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              CupertinoIcons.back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppleColors.systemGreen,
                                  AppleColors.systemTeal,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              CupertinoIcons.folder_fill,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Local Music',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Play music from your device',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppleColors.systemRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppleColors.systemRed.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: AppleColors.systemRed,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppleColors.systemRed,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _errorMessage = null),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: AppleColors.systemRed,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Scanning progress
              if (_isScanning)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const CupertinoActivityIndicator(radius: 14),
                            const SizedBox(height: 16),
                            Text(
                              'Scanning music files...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_scannedFiles / $_totalFiles files',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _totalFiles > 0
                                    ? _scannedFiles / _totalFiles
                                    : null,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppleColors.systemGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      isDark: isDark,
                    ),
                  ),
                ),

              // Music directories section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Music Directories',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              GestureDetector(
                                onTap: _addDirectory,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppleColors.systemGreen,
                                        AppleColors.systemTeal,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.plus,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Add Folder',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (directories.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.folder_badge_plus,
                                    size: 48,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No music directories added',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap "Add Folder" to select your music folders',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...directories.map(
                              (dir) => _buildDirectoryTile(dir, isDark),
                            ),
                        ],
                      ),
                    ),
                    isDark: isDark,
                  ),
                ),
              ),

              // Library stats
              if (service != null && service.isInitialized && !_isScanning)
                SliverToBoxAdapter(
                  child: FutureBuilder<List<dynamic>>(
                    future: Future.wait([
                      service.getTracks(),
                      service.getAlbums(),
                      service.getArtists(),
                    ]),
                    builder: (context, snapshot) {
                      final trackCount = snapshot.data?[0]?.length ?? 0;
                      final albumCount = snapshot.data?[1]?.length ?? 0;
                      final artistCount = snapshot.data?[2]?.length ?? 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Library',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Tracks',
                                        trackCount.toString(),
                                        CupertinoIcons.music_note,
                                        AppleColors.systemPink,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Albums',
                                        albumCount.toString(),
                                        CupertinoIcons.square_stack,
                                        AppleColors.systemPurple,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Artists',
                                        artistCount.toString(),
                                        CupertinoIcons.person_2,
                                        AppleColors.systemBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),

              // Artwork Settings
              if (service != null && service.isInitialized && !_isScanning)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Album Art',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Album art is fetched from embedded metadata, local images, and online sources',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildArtworkSettingTile(
                              'Fetch Online Artwork',
                              'Download missing artwork from MusicBrainz & Cover Art Archive',
                              service.fetchOnlineArtwork,
                              (value) async {
                                await service.setFetchOnlineArtwork(value);
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildArtworkActionTile(
                              'Clear Artwork Cache',
                              'Remove cached artwork from online sources',
                              CupertinoIcons.trash,
                              AppleColors.systemRed,
                              () async {
                                final confirmed = await showCupertinoDialog<bool>(
                                  context: context,
                                  builder: (ctx) => CupertinoAlertDialog(
                                    title: const Text('Clear Cache?'),
                                    content: const Text(
                                      'This will remove all cached online artwork. Your local album art files will not be affected.',
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Clear'),
                                      ),
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true && mounted) {
                                  await service.clearArtworkCache();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Artwork cache cleared',
                                        ),
                                        backgroundColor:
                                            AppleColors.systemGreen,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      isDark: isDark,
                    ),
                  ),
                ),

              // Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Scan button
                      GestureDetector(
                        onTap: _isScanning ? null : _scanDirectories,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isScanning
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_2_circlepath,
                                color: _isScanning
                                    ? Colors.white.withOpacity(0.4)
                                    : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isScanning ? 'Scanning...' : 'Scan for Music',
                                style: TextStyle(
                                  color: _isScanning
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (widget.isInitialSetup) ...[
                        const SizedBox(height: 12),
                        // Continue button
                        GestureDetector(
                          onTap: _isScanning ? null : _continueToApp,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppleColors.systemGreen,
                                  AppleColors.systemTeal,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppleColors.systemGreen.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.arrow_right,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Back to login
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Back to Server Selection',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryTile(String dirPath, bool isDark) {
    // Get just the folder name for display
    final folderName = dirPath.split('/').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppleColors.systemGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.folder_fill,
              color: AppleColors.systemGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dirPath,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeDirectory(dirPath),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                CupertinoIcons.trash,
                color: AppleColors.systemRed.withOpacity(0.8),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(isDark ? 0.12 : 0.2),
                Colors.white.withOpacity(isDark ? 0.05 : 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.15 : 0.25),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildArtworkSettingTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppleColors.systemPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.photo,
              color: AppleColors.systemPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppleColors.systemPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withOpacity(0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
