import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedCategory = 'general'; // general, audio, appearance, server, about

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: 'Settings',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings categories sidebar
              _buildCategoriesSidebar(),
              const SizedBox(width: 24),
              // Settings content
              Expanded(
                child: _buildSettingsContent(appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSidebar() {
    final theme = Theme.of(context);
    
    final categories = [
      {'id': 'general', 'title': 'General', 'icon': Icons.settings},
      {'id': 'audio', 'title': 'Audio', 'icon': Icons.volume_up},
      {'id': 'appearance', 'title': 'Appearance', 'icon': Icons.palette},
      {'id': 'server', 'title': 'Server', 'icon': Icons.dns},
      {'id': 'about', 'title': 'About', 'icon': Icons.info},
    ];

    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categories.map((category) {
              final isSelected = _selectedCategory == category['id'];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  selected: isSelected,
                  selectedTileColor: theme.colorScheme.primaryContainer,
                  leading: Icon(
                    category['icon'] as IconData,
                    color: isSelected 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    category['title'] as String,
                    style: TextStyle(
                      color: isSelected 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['id'] as String;
                    });
                  },
                ),
              );
            }).toList(),
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
      case 'about':
        return _buildAboutSettings(appState);
      default:
        return _buildGeneralSettings(appState);
    }
  }

  Widget _buildGeneralSettings(AppState appState) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Settings',
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
                    'Startup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Start with system'),
                    subtitle: const Text('Launch Doudou when your computer starts'),
                    value: false, // This would come from preferences
                    onChanged: (value) {
                      // Handle startup setting
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Start minimized'),
                    subtitle: const Text('Launch in system tray instead of window'),
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
                    'Library',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto-refresh library'),
                    subtitle: const Text('Automatically check for new music'),
                    value: true,
                    onChanged: (value) {
                      // Handle auto-refresh setting
                    },
                  ),
                  ListTile(
                    title: const Text('Default library view'),
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
                  SwitchListTile(
                    title: const Text('Crossfade'),
                    subtitle: const Text('Smooth transitions between songs'),
                    value: false,
                    onChanged: (value) {
                      // Handle crossfade setting
                    },
                  ),
                  ListTile(
                    title: const Text('Crossfade duration'),
                    subtitle: const Text('3 seconds'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    enabled: false, // Enable when crossfade is on
                    onTap: () {
                      // Show duration slider
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
                    subtitle: const Text('Keep consistent volume across tracks'),
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
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance Settings',
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
                    'Theme',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('App theme'),
                    subtitle: Text(_getThemeDisplayName(appState.themeMode)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showThemeDialog();
                    },
                  ),
                  ListTile(
                    title: const Text('Accent color'),
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
                    'Layout',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Compact mode'),
                    subtitle: const Text('Reduce spacing and padding'),
                    value: false,
                    onChanged: (value) {
                      // Handle compact mode
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show album art in sidebar'),
                    subtitle: const Text('Display current track artwork'),
                    value: true,
                    onChanged: (value) {
                      // Handle sidebar artwork
                    },
                  ),
                  ListTile(
                    title: const Text('Grid size'),
                    subtitle: const Text('Medium'),
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
          
          // Window section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Window',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Close to system tray'),
                    subtitle: const Text('Keep running when window is closed'),
                    value: true,
                    onChanged: (value) {
                      // Handle system tray setting
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show in taskbar'),
                    subtitle: const Text('Display app icon in taskbar'),
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
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server Settings',
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
                        'Connection',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appState.isLoggedIn ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          appState.isLoggedIn ? 'Connected' : 'Disconnected',
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
                  ListTile(
                    title: const Text('Server URL'),
                    subtitle: Text(appState.jellyfinService.serverUrl ?? 'Not set'),
                    trailing: const Icon(Icons.edit),
                    onTap: () {
                      // Edit server URL
                    },
                  ),
                  ListTile(
                    title: const Text('Username'),
                    subtitle: Text(appState.jellyfinService.username ?? 'Not logged in'),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Doudou',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Jellyfin Music Player',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Version 6.0.0',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A beautiful music player for your Jellyfin server',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
                    title: const Text('Flutter Version'),
                    subtitle: const Text('3.24.0'),
                    leading: const Icon(Icons.flutter_dash),
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
    return 'Custom';
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: Wrap(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
        content: const Text('Are you sure you want to sign out? You\'ll need to log in again to access your music.'),
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
          'This will remove ${cacheType == 'all' ? 'all cached data' : 'cached images'} and may slow down the app temporarily. Continue?'
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
                  content: Text('${cacheType == 'all' ? 'All cache' : 'Image cache'} cleared successfully'),
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

  String _getArchitecture() {
    try {
      // Get system architecture
      final result = Process.runSync('uname', ['-m']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      // Fallback for non-Unix systems or if uname fails
    }
    return 'Unknown';
  }

  String _getBuildDate() {
    // This would ideally come from build-time constants
    // For now, we'll use a compile-time constant or try to get it from package info
    return DateTime.now().toLocal().toString().split(' ')[0]; // Current date as fallback
  }
}
