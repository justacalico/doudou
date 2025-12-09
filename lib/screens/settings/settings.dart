import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../login/login.dart';
import 'partials/account_information.dart';
import 'partials/audio_settings.dart';
import 'partials/language_settings.dart';
import 'logs_viewer.dart';
import '../../cardboard/pages/vr_player.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '...';
  String _cacheSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadCacheSize();
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

  Future<void> _loadCacheSize() async {
    try {
      final appState = context.read<AppState>();
      final cacheStats = await appState.getCacheStats();
      final dataCache = cacheStats['data_cache'] as Map<String, int>? ?? {};
      final imageCacheSize = cacheStats['image_cache_size'] as int? ?? 0;
      
      int totalDataEntries = 0;
      for (final count in dataCache.values) {
        totalDataEntries += count;
      }
      
      String sizeText = '';
      if (imageCacheSize > 1024 * 1024) {
        sizeText = '${(imageCacheSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else if (imageCacheSize > 1024) {
        sizeText = '${(imageCacheSize / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeText = '$imageCacheSize bytes';
      }
      
      setState(() {
        _cacheSize = '$totalDataEntries items, $sizeText';
      });
    } catch (e) {
      setState(() {
        _cacheSize = 'Unknown';
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
            return CustomScrollView(
              slivers: [
                // Custom header for iOS-style left-aligned title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context).settings,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Account Information Section
                const SliverToBoxAdapter(
                  child: AccountInformationSection(),
                ),

                // Audio Settings Section
                const SliverToBoxAdapter(
                  child: AudioSettingsSection(),
                ),

                // Language Settings Section
                const SliverToBoxAdapter(
                  child: LanguageSettingsSection(),
                ),

                // Player Interface Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(AppLocalizations.of(context).playerInterface),
                        _buildSwitchTile(
                          icon: CupertinoIcons.rectangle_3_offgrid,
                          title: AppLocalizations.of(context).dynamicIslePlayer,
                          subtitle: AppLocalizations.of(context).useModernFloatingPlayer,
                          value: appState.useDynamicIsle,
                          onChanged: (value) => appState.toggleDynamicIsle(value),
                        ),
                        // VR Mode button (mobile only)
                        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                                       defaultTargetPlatform == TargetPlatform.iOS))
                          _buildSettingTile(
                            icon: CupertinoIcons.viewfinder,
                            title: AppLocalizations.of(context).vrMode,
                            subtitle: AppLocalizations.of(context).launchVRPlayer,
                            onTap: () => _launchVRMode(context),
                          ),
                      ],
                    ),
                  ),
                ),

                // Storage & Cache Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E), // Dark gray background instead of pure black
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(AppLocalizations.of(context).storageAndCache),
                        _buildSettingTile(
                          icon: CupertinoIcons.folder,
                          title: AppLocalizations.of(context).cacheSize,
                          subtitle: _cacheSize,
                          onTap: () => _showCacheDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.trash,
                          title: AppLocalizations.of(context).clearCacheOptions,
                          subtitle: AppLocalizations.of(context).freeUpStorage,
                          onTap: () => _showClearCacheDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.refresh,
                          title: AppLocalizations.of(context).cleanExpiredCache,
                          subtitle: AppLocalizations.of(context).removeOldCachedData,
                          onTap: () => _cleanExpiredCache(context),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Logs & Diagnostics Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(AppLocalizations.of(context).logsAndDiagnostics),
                        _buildSwitchTile(
                          icon: CupertinoIcons.doc_text,
                          title: AppLocalizations.of(context).enableLogging,
                          subtitle: AppLocalizations.of(context).recordAppActivity,
                          value: appState.loggingEnabled,
                          onChanged: (value) => appState.toggleLogging(value),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.doc_text_viewfinder,
                          title: AppLocalizations.of(context).viewApplicationLogs,
                          subtitle: AppLocalizations.of(context).viewExportLogs,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const LogsViewerScreen(),
                            ),
                          ),
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
                      color: const Color(0xFF1C1C1E), // Dark gray background instead of pure black
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(AppLocalizations.of(context).about),
                        _buildInfoTile(
                          icon: CupertinoIcons.info,
                          title: AppLocalizations.of(context).appVersion,
                          subtitle: _appVersion,
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.doc_text,
                          title: AppLocalizations.of(context).licenses,
                          subtitle: AppLocalizations.of(context).viewOpenSourceLicenses,
                          onTap: () => _showLicensesDialog(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.link,
                          title: AppLocalizations.of(context).gitLabRepository,
                          subtitle: AppLocalizations.of(context).viewSourceAndContribute,
                          onTap: () => _openGitLabPage(context),
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.heart,
                          title: AppLocalizations.of(context).supportDevelopment,
                          subtitle: AppLocalizations.of(context).helpSupportProject,
                          onTap: () => _showSupportDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Refresh Data Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF007AFF),
                          Color(0xFF5856D6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      onPressed: appState.isLoading ? null : () => _refreshLibraryData(context, appState),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (appState.isLoading)
                            const CupertinoActivityIndicator(
                              color: Color(0xFFFFFFFF),
                            )
                          else
                            const Icon(
                              CupertinoIcons.refresh,
                              color: Color(0xFFFFFFFF),
                              size: 20,
                            ),
                          const SizedBox(width: 12),
                          Text(
                            appState.isLoading ? AppLocalizations.of(context).refreshing : AppLocalizations.of(context).refreshLibrary,
                            style: TextStyle(
                              color: appState.isLoading ? const Color(0xFFFFFFFF).withOpacity(0.6) : const Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.square_arrow_left, 
                            color: Color(0xFFFFFFFF),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).signOut,
                            style: const TextStyle(
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

                const SliverToBoxAdapter(child: SizedBox(height: 20)), // Reduced spacing to prevent overlap with now playing
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

  void _launchVRMode(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const VRPlayerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.confirmSignOut),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.cancel),
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
            child: Text(l10n.signOut),
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

    if (!context.mounted) return;

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
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      _showCacheClearedDialog(context, 'Data');
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Failed to clear data cache: $e');
    }
  }

  void _clearImageCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearImageCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      _showCacheClearedDialog(context, 'Image');
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Failed to clear image cache: $e');
    }
  }

  void _clearAllCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearAllCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      _showCacheClearedDialog(context, 'All');
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Failed to clear cache: $e');
    }
  }

  void _cleanExpiredCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.cleanupExpiredCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
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
      if (!context.mounted) return;
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
    const url = 'https://gitlab.com/Openlyst/doudou';
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('GitLab Repository'),
          content: const Text('The GitLab URL has been copied to your clipboard!\n\nhttps://gitlab.com/Openlyst/doudou\n\nYou can now paste it into your browser to visit the repository.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
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

  Future<void> _refreshLibraryData(BuildContext context, AppState appState) async {
    try {
      // Show a brief feedback to user
      HapticFeedback.lightImpact();
      
      // Force refresh the library data from the server (bypassing cache)
      await appState.refreshLibraryData();
      
      // Show success feedback
      if (context.mounted) {
        _showRefreshSuccessDialog(context);
      }
    } catch (e) {
      // Show error dialog if refresh fails
      if (context.mounted) {
        _showRefreshErrorDialog(context, e.toString());
      }
    }
  }

  void _showRefreshSuccessDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Library Refreshed'),
        content: const Text('Your music library has been successfully updated with the latest content from the server.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showRefreshErrorDialog(BuildContext context, String error) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Refresh Failed'),
        content: Text('Failed to refresh library data. Please check your connection and try again.\n\nError: $error'),
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
