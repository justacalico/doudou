import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../mobile/widgets/apple_design/apple_theme.dart';
import '../templates/page_template.dart';
import '../../../providers/app_state.dart';
import '../../../services/logging_service.dart';
import '../../../services/base_service.dart';
import '../../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedCategory =
      'general'; // general, audio, appearance, server, about

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: l10n.settings,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings categories sidebar
              _buildCategoriesSidebar(),
              const SizedBox(width: 24),
              // Settings content
              Expanded(child: _buildSettingsContent(appState)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSidebar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final isLocalMusic =
        appState.mediaServiceManager.currentServerType == ServerType.local;

    final categories = [
      {
        'id': 'general',
        'title': l10n.generalSettings.split(' ').first,
        'icon': Icons.settings_rounded,
      },
      {
        'id': 'audio',
        'title': l10n.audioSettings.split(' ').first,
        'icon': Icons.volume_up_rounded,
      },
      {
        'id': 'appearance',
        'title': l10n.appearanceSettings.split(' ').first,
        'icon': Icons.palette_rounded,
      },
      {
        'id': 'server',
        'title': isLocalMusic ? 'Local Music' : l10n.server,
        'icon': isLocalMusic ? Icons.folder_rounded : Icons.dns_rounded,
      },
      {
        'id': 'logs',
        'title': l10n.logsAndDiagnostics.split(' ').first,
        'icon': Icons.description_rounded,
      },
      {
        'id': 'about',
        'title': l10n.aboutDoudou.split(' ').first,
        'icon': Icons.info_rounded,
      },
    ];

    return SizedBox(
      width: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppleDesignSystem.blurThin,
            sigmaY: AppleDesignSystem.blurThin,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppleColors.backgroundSecondaryDark.withValues(alpha: 0.7)
                  : AppleColors.backgroundSecondary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(
                AppleDesignSystem.radiusMedium,
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(AppleDesignSystem.spacing8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: categories.map((category) {
                final isSelected = _selectedCategory == category['id'];
                return _AppleSettingsCategory(
                  icon: category['icon'] as IconData,
                  title: category['title'] as String,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['id'] as String;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(AppState appState) {
    switch (_selectedCategory) {
      case 'general':
        return _buildGeneralSettings(appState);
      case 'audio':
        return _buildAudioSettings(appState);
      case 'appearance':
        return _buildAppearanceSettings(appState);
      case 'server':
        return _buildServerSettings(appState);
      case 'logs':
        return _buildLogsSettings();
      case 'about':
        return _buildAboutSettings(appState);
      default:
        return _buildGeneralSettings(appState);
    }
  }

  Widget _buildGeneralSettings(AppState appState) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.generalSettings,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Startup section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.startup,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.startWithSystem),
                    subtitle: Text(l10n.launchOnStartup),
                    value: false, // This would come from preferences
                    onChanged: (value) {
                      // Handle startup setting
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.startMinimized),
                    subtitle: Text(l10n.launchInTray),
                    value: false,
                    onChanged: (value) {
                      // Handle minimize setting
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Library section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.library,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.autoRefreshLibrary),
                    subtitle: Text(l10n.autoCheckForMusic),
                    value: true,
                    onChanged: (value) {
                      // Handle auto-refresh setting
                    },
                  ),
                  ListTile(
                    title: Text(l10n.defaultLibraryView),
                    subtitle: const Text('Albums'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show library view options
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Downloads section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloads',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Download location'),
                    subtitle: const Text('~/Music/Doudou'),
                    trailing: const Icon(Icons.folder_open),
                    onTap: () {
                      // Open folder picker
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Download over cellular'),
                    subtitle: const Text('Allow downloads on mobile data'),
                    value: false,
                    onChanged: (value) {
                      // Handle cellular downloads setting
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSettings(AppState appState) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Playback section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playback',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Audio quality'),
                    subtitle: const Text('High (320 kbps)'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show quality options
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Volume section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Volume',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Volume normalization'),
                    subtitle: const Text(
                      'Keep consistent volume across tracks',
                    ),
                    value: true,
                    onChanged: (value) {
                      // Handle volume normalization
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Fade on pause/resume'),
                    subtitle: const Text('Smooth volume transitions'),
                    value: true,
                    onChanged: (value) {
                      // Handle fade setting
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Audio device section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Device',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Output device'),
                    subtitle: const Text('System default'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show device options
                    },
                  ),
                  ListTile(
                    title: const Text('Buffer size'),
                    subtitle: const Text('Auto'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show buffer options
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings(AppState appState) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceSettings,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Theme section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.theme,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(l10n.appTheme),
                    subtitle: Text(_getThemeDisplayName(appState.themeMode)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showThemeDialog();
                    },
                  ),
                  ListTile(
                    title: Text(l10n.accentColor),
                    subtitle: Text(_getColorDisplayName(appState.accentColor)),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: appState.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      _showColorDialog();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Layout section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.layout,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.compactMode),
                    subtitle: Text(l10n.reduceSpacing),
                    value: false,
                    onChanged: (value) {
                      // Handle compact mode
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.showAlbumArtSidebar),
                    subtitle: Text(l10n.displayCurrentArtwork),
                    value: true,
                    onChanged: (value) {
                      // Handle sidebar artwork
                    },
                  ),
                  ListTile(
                    title: Text(l10n.gridSize),
                    subtitle: Text(l10n.medium),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show grid size options
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Language section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.language,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l10n.selectLanguage),
                    subtitle: Text(_getCurrentLanguageDisplayName(appState)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showLanguageDialog(appState);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Window section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.window,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.closeToTray),
                    subtitle: Text(l10n.keepRunningWhenClosed),
                    value: true,
                    onChanged: (value) {
                      // Handle system tray setting
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.showInTaskbar),
                    subtitle: Text(l10n.displayInTaskbar),
                    value: true,
                    onChanged: (value) {
                      // Handle taskbar setting
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettings(AppState appState) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLocalMusic =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    final localService = appState.mediaServiceManager.localMusicService;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLocalMusic ? 'Local Music Settings' : l10n.serverSettings,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Connection section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isLocalMusic ? 'Music Source' : l10n.connection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: appState.isLoggedIn
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          appState.isLoggedIn
                              ? (isLocalMusic ? 'Active' : l10n.authenticated)
                              : 'Disconnected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLocalMusic && localService != null) ...[
                    // Local Music specific settings
                    ListTile(
                      title: const Text('Music Directories'),
                      subtitle: Text(
                        '${localService.musicDirectories.length} folder${localService.musicDirectories.length != 1 ? 's' : ''} configured',
                      ),
                      trailing: const Icon(Icons.folder),
                    ),
                    // List configured directories
                    ...localService.musicDirectories.map(
                      (dir) => ListTile(
                        leading: const Icon(Icons.folder_open, size: 20),
                        title: Text(
                          dir.split('/').last,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          dir,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeLocalDirectory(appState, dir),
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Add Directory'),
                      leading: const Icon(Icons.create_new_folder),
                      onTap: () => _addLocalDirectory(appState),
                    ),
                    ListTile(
                      title: const Text('Rescan Library'),
                      leading: const Icon(Icons.refresh),
                      subtitle: const Text('Scan directories for new music'),
                      onTap: () => _rescanLocalLibrary(appState),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Fetch Online Artwork'),
                      subtitle: const Text(
                        'Download album art from MusicBrainz',
                      ),
                      value: localService.fetchOnlineArtwork,
                      onChanged: (value) async {
                        await localService.setFetchOnlineArtwork(value);
                        setState(() {});
                      },
                    ),
                  ] else ...[
                    // Server-based settings (Jellyfin, etc.)
                    ListTile(
                      title: const Text('Server URL'),
                      subtitle: Text(
                        appState.jellyfinService.serverUrl ?? 'Not set',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        // Edit server URL
                      },
                    ),
                    ListTile(
                      title: const Text('Username'),
                      subtitle: Text(
                        appState.jellyfinService.username ?? 'Not logged in',
                      ),
                      trailing: const Icon(Icons.person),
                      onTap: () {
                        // Show user info
                      },
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Test Connection'),
                      leading: const Icon(Icons.wifi_tethering),
                      onTap: () {
                        _testConnection(appState);
                      },
                    ),
                  ],
                  ListTile(
                    title: const Text('Sign Out'),
                    leading: const Icon(Icons.logout),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () {
                      _showSignOutDialog(appState);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cache section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cache',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Cache size'),
                    subtitle: const Text('Calculating...'),
                    trailing: const Icon(Icons.folder),
                    onTap: () {
                      // Show cache details
                    },
                  ),
                  ListTile(
                    title: const Text('Clear image cache'),
                    subtitle: const Text('Free up storage space'),
                    trailing: const Icon(Icons.clear),
                    onTap: () {
                      _showClearCacheDialog('images');
                    },
                  ),
                  if (isLocalMusic && localService != null)
                    ListTile(
                      title: const Text('Clear artwork cache'),
                      subtitle: const Text('Remove downloaded album artwork'),
                      trailing: const Icon(Icons.image_not_supported),
                      onTap: () async {
                        await localService.clearArtworkCache();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Artwork cache cleared'),
                            ),
                          );
                        }
                      },
                    ),
                  ListTile(
                    title: const Text('Clear all cache'),
                    subtitle: const Text('Remove all cached data'),
                    trailing: const Icon(Icons.delete_sweep),
                    onTap: () {
                      _showClearCacheDialog('all');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addLocalDirectory(AppState appState) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Music Directory',
    );

    if (result != null) {
      try {
        await appState.mediaServiceManager.addLocalMusicDirectory(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added directory: ${result.split('/').last}'),
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding directory: $e')));
        }
      }
    }
  }

  Future<void> _removeLocalDirectory(
    AppState appState,
    String directory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Directory'),
        content: Text(
          'Remove "${directory.split('/').last}" from your music sources?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final localService = appState.mediaServiceManager.localMusicService;
      await localService?.removeDirectory(directory);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Directory removed')));
        setState(() {});
      }
    }
  }

  Future<void> _rescanLocalLibrary(AppState appState) async {
    final localService = appState.mediaServiceManager.localMusicService;
    if (localService == null) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Scanning Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return StreamBuilder<String>(
                  stream: Stream.periodic(
                    const Duration(milliseconds: 500),
                    (_) => localService.isScanning ? 'Scanning...' : 'Complete',
                  ),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? 'Starting...');
                  },
                );
              },
            ),
          ],
        ),
      ),
    );

    try {
      await localService.scanDirectories();
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Library scan complete')));
        // Reload library data
        await appState.loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
    }
  }

  Widget _buildLogsSettings() {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logs & Diagnostics',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Logging toggle
          Card(
            child: SwitchListTile(
              title: const Text('Enable Logging'),
              subtitle: const Text(
                'Record app activity for troubleshooting. Disabled by default to improve performance.',
              ),
              value: appState.loggingEnabled,
              onChanged: (value) => appState.toggleLogging(value),
              secondary: Icon(
                Icons.bug_report,
                color: appState.loggingEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logs viewer
          _DesktopLogsViewer(theme: theme),
        ],
      ),
    );
  }

  Widget _buildAboutSettings(AppState appState) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Doudou',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // App info section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/icon.png', width: 80, height: 80),
                    const SizedBox(height: 24),
                    Text(
                      'Doudou',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version =
                            snapshot.data?.version ?? 'Error: Unknown';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Version $version',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'A beautiful music player for anyone anywhere.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Links section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Links',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('GitHub Repository'),
                    subtitle: const Text('Source code and issues'),
                    leading: const Icon(Icons.code),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open GitHub
                    },
                  ),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('How we handle your data'),
                    leading: const Icon(Icons.privacy_tip),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open privacy policy
                    },
                  ),
                  ListTile(
                    title: const Text('Terms of Service'),
                    subtitle: const Text('Usage terms and conditions'),
                    leading: const Icon(Icons.description),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open terms
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // System info section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Platform'),
                    subtitle: Text(_getPlatformInfo()),
                    leading: const Icon(Icons.computer),
                  ),
                  ListTile(
                    title: const Text('Build Date'),
                    subtitle: Text(_getBuildDate()),
                    leading: const Icon(Icons.calendar_today),
                  ),
                  ListTile(
                    title: const Text('Operating System'),
                    subtitle: Text(_getOSVersion()),
                    leading: const Icon(Icons.settings_system_daydream),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final appState = context.read<AppState>();
    final currentTheme = _themeModeToString(appState.themeMode);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System Default'),
              leading: Radio<String>(
                value: 'system',
                groupValue: currentTheme,
                onChanged: (value) {
                  Navigator.pop(context);
                  appState.setThemeMode(ThemeMode.system);
                },
              ),
            ),
            ListTile(
              title: const Text('Light'),
              leading: Radio<String>(
                value: 'light',
                groupValue: currentTheme,
                onChanged: (value) {
                  Navigator.pop(context);
                  appState.setThemeMode(ThemeMode.light);
                },
              ),
            ),
            ListTile(
              title: const Text('Dark'),
              leading: Radio<String>(
                value: 'dark',
                groupValue: currentTheme,
                onChanged: (value) {
                  Navigator.pop(context);
                  appState.setThemeMode(ThemeMode.dark);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String _getThemeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  String _getColorDisplayName(Color color) {
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.green) return 'Green';
    if (color == Colors.orange) return 'Orange';
    if (color == Colors.red) return 'Red';
    if (color == Colors.teal) return 'Teal';

    // Show hex value for custom colors
    final hex = color.value.toRadixString(16).substring(2).toUpperCase();
    return 'Custom (#$hex)';
  }

  void _showColorDialog() {
    final appState = context.read<AppState>();
    final colors = [
      {'name': 'Purple', 'color': Colors.purple},
      {'name': 'Blue', 'color': Colors.blue},
      {'name': 'Green', 'color': Colors.green},
      {'name': 'Orange', 'color': Colors.orange},
      {'name': 'Red', 'color': Colors.red},
      {'name': 'Teal', 'color': Colors.teal},
    ];

    // Check if current color is one of the presets
    final isCustomColor = !colors.any(
      (colorData) =>
          (colorData['color'] as Color).value == appState.accentColor.value,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset colors
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((colorData) {
                  final color = colorData['color'] as Color;
                  final isSelected = color.value == appState.accentColor.value;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      appState.setAccentColor(color);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.outline,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            Text(
                              colorData['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Custom color option
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showCustomColorPicker(appState);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCustomColor
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: isCustomColor ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCustomColor
                              ? appState.accentColor
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Custom Color'),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker(AppState appState) {
    showDialog(
      context: context,
      builder: (context) => _CustomColorPickerDialog(
        initialColor: appState.accentColor,
        onColorSelected: (color) {
          appState.setAccentColor(color);
        },
      ),
    );
  }

  void _testConnection(AppState appState) {
    // This would test the Jellyfin connection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          appState.isLoggedIn
              ? 'Connection successful!'
              : 'Connection failed. Please check your settings.',
        ),
        backgroundColor: appState.isLoggedIn ? Colors.green : Colors.red,
      ),
    );
  }

  void _showSignOutDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You\'ll need to log in again to access your music.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              appState.logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(String cacheType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear ${cacheType == 'all' ? 'All' : 'Image'} Cache'),
        content: Text(
          'This will remove ${cacheType == 'all' ? 'all cached data' : 'cached images'} and may slow down the app temporarily. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle cache clearing
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${cacheType == 'all' ? 'All cache' : 'Image cache'} cleared successfully',
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  String _getPlatformInfo() {
    final platform = Platform.operatingSystem;
    final architecture = _getArchitecture();

    switch (platform) {
      case 'linux':
        return 'Linux Desktop ($architecture)';
      case 'windows':
        return 'Windows Desktop ($architecture)';
      case 'macos':
        return 'macOS Desktop ($architecture)';
      default:
        return '$platform ($architecture)';
    }
  }

  String _getArchitecture() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = Process.runSync('uname', ['-m']);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      } else if (Platform.isWindows) {
        final result = Process.runSync('wmic', [
          'computersystem',
          'get',
          'systemtype',
          '/value',
        ]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          if (output.contains('x64')) return 'x64';
          if (output.contains('x86')) return 'x86';
        }
      }
    } catch (e) {
      // Fallback if commands fail
    }
    return 'Unknown';
  }

  String _getBuildDate() {
    // In a real build system, this would come from build-time constants
    // For development, we can use the compile date or a fixed date
    return '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
  }

  String _getOSVersion() {
    try {
      if (Platform.isLinux) {
        // Try to get Linux distribution info
        final result = Process.runSync('lsb_release', ['-d', '-s']);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim().replaceAll('"', '');
        }
        // Fallback to kernel version
        final kernelResult = Process.runSync('uname', ['-r']);
        if (kernelResult.exitCode == 0) {
          return 'Linux ${kernelResult.stdout.toString().trim()}';
        }
      } else if (Platform.isWindows) {
        final result = Process.runSync('wmic', [
          'os',
          'get',
          'Caption',
          '/value',
        ]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'Caption=(.+)').firstMatch(output);
          if (match != null) {
            return match.group(1)?.trim() ?? 'Windows';
          }
        }
      } else if (Platform.isMacOS) {
        final result = Process.runSync('sw_vers', ['-productVersion']);
        if (result.exitCode == 0) {
          return 'macOS ${result.stdout.toString().trim()}';
        }
      }
    } catch (e) {
      // Fallback if commands fail
    }
    return Platform.operatingSystem;
  }

  String _getCurrentLanguageDisplayName(AppState appState) {
    final locale = appState.locale;
    if (locale == null) {
      return 'System default';
    }
    return _getLanguageNameForLocale(locale);
  }

  String _getLanguageNameForLocale(Locale locale) {
    const languageNames = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
      'ar': 'العربية',
      'hi': 'हिन्दी',
      'nl': 'Nederlands',
      'pl': 'Polski',
      'tr': 'Türkçe',
      'vi': 'Tiếng Việt',
      'th': 'ไทย',
      'id': 'Indonesia',
      'ms': 'Melayu',
      'uk': 'Українська',
      'cs': 'Čeština',
      'sv': 'Svenska',
      'da': 'Dansk',
      'fi': 'Suomi',
      'no': 'Norsk',
      'he': 'עברית',
      'el': 'Ελληνικά',
      'ro': 'Română',
      'hu': 'Magyar',
      'sk': 'Slovenčina',
      'bg': 'Български',
      'hr': 'Hrvatski',
      'sr': 'Српски',
      'sl': 'Slovenščina',
      'et': 'Eesti',
      'lv': 'Latviešu',
      'lt': 'Lietuvių',
    };

    final baseName = languageNames[locale.languageCode] ?? locale.languageCode;

    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '$baseName (${locale.countryCode})';
    }

    return baseName;
  }

  void _showLanguageDialog(AppState appState) {
    final currentLocale = appState.locale;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: ListView(
            children: [
              // System default option
              RadioListTile<Locale?>(
                title: const Text('System default'),
                value: null,
                groupValue: currentLocale,
                onChanged: (value) {
                  Navigator.pop(context);
                  appState.setLocale(null);
                },
              ),
              const Divider(),
              // Supported locales
              ...AppLocalizations.supportedLocales.map((locale) {
                return RadioListTile<Locale?>(
                  title: Text(_getLanguageNameForLocale(locale)),
                  value: locale,
                  groupValue: currentLocale,
                  onChanged: (value) {
                    Navigator.pop(context);
                    appState.setLocale(locale);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// Desktop Logs Viewer Widget
class _DesktopLogsViewer extends StatefulWidget {
  final ThemeData theme;

  const _DesktopLogsViewer({required this.theme});

  @override
  State<_DesktopLogsViewer> createState() => _DesktopLogsViewerState();
}

class _DesktopLogsViewerState extends State<_DesktopLogsViewer> {
  final LoggingService _loggingService = LoggingService();
  List<String> _logs = [];
  Map<String, dynamic> _logStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = _loggingService.getMemoryLogs();
      final stats = await _loggingService.getLogStats();

      setState(() {
        _logs = logs;
        _logStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logs = ['Error loading logs: $e'];
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes bytes';
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logs = await _loggingService.exportLogs();
      final file = File(
        '${Platform.environment['HOME']}/doudou_logs_export.txt',
      );
      await file.writeAsString(logs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs exported to: ${file.path}'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export logs: $e'),
            backgroundColor: widget.theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
          'Are you sure you want to clear all logs? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: widget.theme.colorScheme.error,
            ),
            child: const Text('Clear'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _loggingService.clearLogs();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Logs',
            style: widget.theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Statistics',
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Log Files',
                          '${_logStats['file_count'] ?? 0}',
                          Icons.insert_drive_file,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Total Size',
                          _formatSize(_logStats['total_size'] ?? 0),
                          Icons.storage,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Memory Logs',
                          '${_logStats['memory_logs'] ?? 0}',
                          Icons.memory,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _loadLogs,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export Logs'),
                    onPressed: _exportLogs,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Clear Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.colorScheme.error,
                      foregroundColor: widget.theme.colorScheme.onError,
                    ),
                    onPressed: _clearLogs,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Logs Viewer
          Card(
            child: Container(
              height: 500,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Logs',
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _logs.isEmpty
                        ? Center(
                            child: Text(
                              'No logs available',
                              style: TextStyle(
                                color:
                                    widget.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: widget.theme.colorScheme.surfaceVariant
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.theme.colorScheme.outline
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log =
                                    _logs[_logs.length -
                                        1 -
                                        index]; // Reverse order
                                Color logColor =
                                    widget.theme.colorScheme.onSurface;

                                if (log.contains('[ERROR]')) {
                                  logColor = widget.theme.colorScheme.error;
                                } else if (log.contains('[WARN]')) {
                                  logColor = Colors.orange;
                                } else if (log.contains('[INFO]')) {
                                  logColor = widget.theme.colorScheme.primary;
                                } else if (log.contains('[DEBUG]')) {
                                  logColor =
                                      widget.theme.colorScheme.onSurfaceVariant;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  child: SelectableText(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: logColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: widget.theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: widget.theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _CustomColorPickerDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late Color _currentColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(
      text: _currentColor.value.toRadixString(16).substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor(Color newColor) {
    setState(() {
      _currentColor = newColor;
      _hexController.text = newColor.value
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
    });
  }

  void _updateFromHex(String hex) {
    if (hex.length == 6) {
      try {
        final hexColor = int.parse('FF$hex', radix: 16);
        setState(() {
          _currentColor = Color(hexColor);
        });
      } catch (e) {
        // Invalid hex, ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8; // Use 80% of screen height max

    return AlertDialog(
      title: const Text('Custom Accent Color'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 350, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color preview
              Container(
                width: double.infinity,
                height: 60, // Reduced height
                decoration: BoxDecoration(
                  color: _currentColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Center(
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      color: _currentColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontSize: 16, // Reduced font size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16), // Reduced spacing
              // RGB Sliders (more compact)
              _buildColorSlider(
                'Red',
                _currentColor.red.toDouble(),
                (value) => _updateColor(
                  Color.fromARGB(
                    255,
                    value.round(),
                    _currentColor.green,
                    _currentColor.blue,
                  ),
                ),
                Colors.red,
              ),

              const SizedBox(height: 12), // Reduced spacing

              _buildColorSlider(
                'Green',
                _currentColor.green.toDouble(),
                (value) => _updateColor(
                  Color.fromARGB(
                    255,
                    _currentColor.red,
                    value.round(),
                    _currentColor.blue,
                  ),
                ),
                Colors.green,
              ),

              const SizedBox(height: 12), // Reduced spacing

              _buildColorSlider(
                'Blue',
                _currentColor.blue.toDouble(),
                (value) => _updateColor(
                  Color.fromARGB(
                    255,
                    _currentColor.red,
                    _currentColor.green,
                    value.round(),
                  ),
                ),
                Colors.blue,
              ),

              const SizedBox(height: 16), // Reduced spacing
              // Hex input
              Row(
                children: [
                  const Text('Hex: #'),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 14), // Smaller text
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'RRGGBB',
                        isDense: true, // More compact
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: _updateFromHex,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12), // Reduced spacing
              // Preset colors for quick selection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick Colors:'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, // Reduced spacing
                runSpacing: 6, // Reduced spacing
                children:
                    [
                          Colors.red,
                          Colors.pink,
                          Colors.purple,
                          Colors.deepPurple,
                          Colors.indigo,
                          Colors.blue,
                          Colors.lightBlue,
                          Colors.cyan,
                          Colors.teal,
                          Colors.green,
                          Colors.lightGreen,
                          Colors.lime,
                          Colors.yellow,
                          Colors.amber,
                          Colors.orange,
                          Colors.deepOrange,
                        ]
                        .map(
                          (color) => InkWell(
                            onTap: () => _updateColor(color),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 28, // Smaller size
                              height: 28, // Smaller size
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onColorSelected(_currentColor);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    Color sliderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.round()}',
          style: Theme.of(context).textTheme.bodySmall, // Smaller text
        ),
        const SizedBox(height: 4), // Reduced spacing
        SizedBox(
          height: 30, // Constrain slider height
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: sliderColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _AppleSettingsCategory extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppleSettingsCategory({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AppleSettingsCategory> createState() => _AppleSettingsCategoryState();
}

class _AppleSettingsCategoryState extends State<_AppleSettingsCategory> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppleDesignSystem.spacing2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppleDesignSystem.durationFast,
            curve: AppleDesignSystem.springCurve,
            padding: const EdgeInsets.symmetric(
              horizontal: AppleDesignSystem.spacing12,
              vertical: AppleDesignSystem.spacing8,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.1))
                  : _isHovered
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                AppleDesignSystem.radiusSmall,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? AppleColors.labelSecondaryDark
                            : AppleColors.labelSecondary),
                ),
                const SizedBox(width: AppleDesignSystem.spacing12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: AppleDesignSystem.typeScaleSubheadline,
                      fontWeight: widget.isSelected
                          ? AppleDesignSystem.weightSemiBold
                          : AppleDesignSystem.weightRegular,
                      color: widget.isSelected
                          ? theme.colorScheme.primary
                          : (isDark
                                ? AppleColors.labelPrimaryDark
                                : AppleColors.labelPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
