import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/app_state.dart';
import '../login/login.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000), // Pure black for OLED
      child: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final server = appState.jellyfinService.currentServer;
            
            return CustomScrollView(
              slivers: [
                // Custom header for iOS-style left-aligned title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
                    child: Row(
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Server Information Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000), // Pure black background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('Server Information'),
                        if (server != null) ...[
                          _buildInfoTile(
                            icon: CupertinoIcons.wifi,
                            title: 'Server URL',
                            subtitle: server.serverUrl,
                          ),
                          _buildInfoTile(
                            icon: CupertinoIcons.person,
                            title: 'User ID',
                            subtitle: server.userId ?? 'Not available',
                          ),
                          _buildInfoTile(
                            icon: CupertinoIcons.checkmark_seal,
                            title: 'Connection Status',
                            subtitle: 'Connected',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Audio Settings Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000), // Pure black background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('Audio Settings'),
                        _buildSettingTile(
                          icon: CupertinoIcons.music_note,
                          title: 'Audio Quality',
                          subtitle: 'High Quality',
                          onTap: () => _showAudioQualityDialog(context),
                        ),
                        _buildSwitchTile(
                          icon: CupertinoIcons.volume_up,
                          title: 'Smart Crossfade',
                          subtitle: 'Smooth transitions between tracks',
                          value: appState.smartCrossfadeEnabled,
                          onChanged: (value) {
                            appState.toggleSmartCrossfade(value);
                          },
                        ),
                        _buildSwitchTile(
                          icon: CupertinoIcons.speaker_2,
                          title: 'Normalize Volume',
                          subtitle: 'Reduces volume differences between tracks',
                          value: appState.normalizeVolumeEnabled,
                          onChanged: (value) {
                            appState.toggleNormalizeVolume(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Display Settings Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000), // Pure black background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('Display Settings'),
                        _buildSwitchTile(
                          icon: CupertinoIcons.moon,
                          title: 'OLED Dark Mode',
                          subtitle: 'True black backgrounds for OLED displays',
                          value: appState.oledDarkModeEnabled,
                          onChanged: (value) {
                            appState.toggleOledDarkMode(value);
                          },
                        ),
                        _buildSwitchTile(
                          icon: CupertinoIcons.photo,
                          title: 'Show Album Art',
                          subtitle: 'Display album artwork in player',
                          value: appState.showAlbumArtEnabled,
                          onChanged: (value) {
                            appState.toggleShowAlbumArt(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Storage & Cache Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000), // Pure black background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('Storage & Cache'),
                        _buildSettingTile(
                          icon: CupertinoIcons.folder,
                          title: 'Cache Size',
                          subtitle: 'Calculating...',
                          onTap: () => _showCacheDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.trash,
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          onTap: () => _showClearCacheDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.refresh,
                          title: 'Clean Expired Cache',
                          subtitle: 'Remove old cached data',
                          onTap: () => _cleanExpiredCache(context),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // About Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000), // Pure black background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('About'),
                        _buildInfoTile(
                          icon: CupertinoIcons.info,
                          title: 'App Version',
                          subtitle: _appVersion,
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.doc_text,
                          title: 'Licenses',
                          subtitle: 'View open source licenses',
                          onTap: () => _showLicensesDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.link,
                          title: 'GitLab Repository',
                          subtitle: 'View source code and contribute',
                          onTap: () => _openGitLabPage(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.heart,
                          title: 'Support Development',
                          subtitle: 'Help support this project',
                          onTap: () => _showSupportDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Logout Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF453A),
                          Color(0xFFFF2D92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF453A).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      onPressed: () => _showLogoutDialog(context, appState),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.square_arrow_left, 
                            color: Color(0xFFFFFFFF),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for mini player
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFFFFF), // Pure white text
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF007AFF), // Blue accent for better contrast
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
                    color: Color(0xFFFFFFFF), // Pure white text
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA), // Lighter gray for better readability
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3A3A3C),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF007AFF), // Blue accent
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
                      color: Color(0xFFFFFFFF), // Pure white text
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA), // Lighter gray
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF666666),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFF30D158) : const Color(0xFF007AFF), // Green when active, blue when inactive
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
                    color: Color(0xFFFFFFFF), // Pure white text
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA), // Lighter gray
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF30D158), // Green for OLED
            trackColor: const Color(0xFF1C1C1E), // Dark track
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppState appState) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? You will need to login again to access your music.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await appState.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Audio Quality'),
        content: const Text('Choose your preferred audio quality. Higher quality uses more bandwidth and storage.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Low (128 kbps)'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Medium (256 kbps)'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('High (320 kbps)'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showCacheDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    
    // Get cache stats
    final cacheStats = await appState.getCacheStats();
    final dataCache = cacheStats['data_cache'] as Map<String, int>? ?? {};
    final imageCacheSize = cacheStats['image_cache_size'] as int? ?? 0;
    
    // Calculate total entries
    int totalDataEntries = 0;
    for (final count in dataCache.values) {
      totalDataEntries += count;
    }
    
    // Format image cache size
    String imageSizeText = '';
    if (imageCacheSize > 0) {
      if (imageCacheSize > 1024 * 1024) {
        imageSizeText = '${(imageCacheSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else if (imageCacheSize > 1024) {
        imageSizeText = '${(imageCacheSize / 1024).toStringAsFixed(1)} KB';
      } else {
        imageSizeText = '$imageCacheSize bytes';
      }
    } else {
      imageSizeText = '0 MB';
    }
    
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Cache Information'),
        content: Text(
          'Cache stores downloaded music metadata and images for faster access.\n\n'
          'Data Cache: $totalDataEntries entries\n'
          'Image Cache: $imageSizeText\n\n'
          'Cached data includes albums, artists, tracks, and playlists.'
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Choose what type of cache to clear:\n\n• Data Cache: Albums, artists, tracks, playlists\n• Image Cache: Downloaded artwork\n• All Cache: Everything'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _clearDataCache(context);
            },
            child: const Text('Clear Data'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _clearImageCache(context);
            },
            child: const Text('Clear Images'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllCache(context);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showCacheClearedDialog(BuildContext context, String type) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Cache Cleared'),
        content: Text('$type cache has been successfully cleared.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _clearDataCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearDataCache();
      _showCacheClearedDialog(context, 'Data');
    } catch (e) {
      _showErrorDialog(context, 'Failed to clear data cache: $e');
    }
  }

  void _clearImageCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearImageCache();
      _showCacheClearedDialog(context, 'Image');
    } catch (e) {
      _showErrorDialog(context, 'Failed to clear image cache: $e');
    }
  }

  void _clearAllCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearAllCache();
      _showCacheClearedDialog(context, 'All');
    } catch (e) {
      _showErrorDialog(context, 'Failed to clear cache: $e');
    }
  }

  void _cleanExpiredCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.cleanupExpiredCache();
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Cache Cleaned'),
          content: const Text('Expired cache entries have been removed.'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog(context, 'Failed to clean expired cache: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Open Source Licenses'),
        content: const Text('This app uses the following open source libraries:\n\n• Flutter\n• just_audio\n• cached_network_image\n• provider\n• dio\n• shared_preferences'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _openGitLabPage(BuildContext context) async {
    const url = 'https://gitlab.com/HttpAnimations/doudou';
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('GitLab Repository'),
            content: const Text('The GitLab URL has been copied to your clipboard!\n\nhttps://gitlab.com/HttpAnimations/doudou\n\nYou can now paste it into your browser to visit the repository.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to copy URL to clipboard. Please visit: $url'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSupportDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Support Development'),
        content: const Text('Thank you for using Doudou! This app is open source and free to use. If you\'d like to support development, consider starring the project on GitLab or contributing to the codebase.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
