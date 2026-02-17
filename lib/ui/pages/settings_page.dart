import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/update_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';

/// Breakpoint: below this width use single-column layout (all sections stacked) instead of sidebar.
const double _kSettingsBreakpoint = 768.0;

/// Settings page: all sections ported from UI/desktop/pages/settings.dart.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _category = 'audio';
  String? _notificationMessage;
  Color? _notificationColor;

  void _showNotification(String message, {Color? color}) {
    setState(() {
      _notificationMessage = message;
      _notificationColor = color;
    });
    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _notificationMessage = null;
          _notificationColor = null;
        });
      }
    });
  }

  Widget _buildNotificationBanner() {
    if (_notificationMessage == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(DesktopTheme.spacingMd),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesktopTheme.spacingMd,
                vertical: DesktopTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: _notificationColor ?? Colors.green,
                borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _notificationMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      setState(() {
                        _notificationMessage = null;
                        _notificationColor = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isLocal =
            appState.mediaServiceManager.currentServerType == ServerType.local;
        return PageTemplate(
          title: l10n.settings,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useSidebar = constraints.maxWidth >= _kSettingsBreakpoint;
              if (useSidebar) {
                return Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Sidebar(
                          selected: _category,
                          onSelect: (v) => setState(() => _category = v),
                          l10n: l10n,
                          isLocalMusic: isLocal,
                        ),
                        const SizedBox(width: DesktopTheme.spacingLg),
                        Expanded(child: _buildContent(appState)),
                      ],
                    ),
                    _buildNotificationBanner(),
                  ],
                );
              }
              return Stack(
                children: [
                  _buildAllSections(appState, l10n, isLocal),
                  _buildNotificationBanner(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(AppState appState) {
    switch (_category) {
      case 'audio':
        return _AudioSection(appState: appState);
      case 'appearance':
        return _AppearanceSection(
          appState: appState,
          onTheme: _showThemeDialog,
          onColor: _showColorDialog,
          onLanguage: () => _showLanguageDialog(appState),
        );
      case 'server':
        return _ServerSection(
          appState: appState,
          onAddDir: _addLocalDirectory,
          onRemoveDir: _removeLocalDirectory,
          onRescan: _rescanLocalLibrary,
          onTestConnection: _testConnection,
          onSignOut: _showSignOutDialog,
          onClearCache: _showClearCacheDialog,
          onShowNotification: _showNotification,
        );
      case 'about':
        return _AboutSection(appState: appState);
      default:
        return _AudioSection(appState: appState);
    }
  }

  Widget _buildAllSections(AppState appState, AppLocalizations l10n, bool isLocal) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AudioSection(appState: appState),
          _AppearanceSection(
            appState: appState,
            onTheme: _showThemeDialog,
            onColor: _showColorDialog,
            onLanguage: () => _showLanguageDialog(appState),
          ),
          _ServerSection(
            appState: appState,
            onAddDir: _addLocalDirectory,
            onRemoveDir: _removeLocalDirectory,
            onRescan: _rescanLocalLibrary,
            onTestConnection: _testConnection,
            onSignOut: _showSignOutDialog,
            onClearCache: _showClearCacheDialog,
            onShowNotification: _showNotification,
          ),
          _AboutSection(appState: appState),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final appState = context.read<AppState>();
    final current = _themeModeToString(appState.themeMode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeRadio(ctx, appState, 'system', current, ThemeMode.system),
            _themeRadio(ctx, appState, 'light', current, ThemeMode.light),
            _themeRadio(ctx, appState, 'dark', current, ThemeMode.dark),
          ],
        ),
      ),
    );
  }

  Widget _themeRadio(BuildContext ctx, AppState appState, String label, String current, ThemeMode mode) {
    return ListTile(
      title: Text(label == 'system' ? 'System Default' : label == 'light' ? 'Light' : 'Dark'),
      leading: Radio<String>(
        value: label,
        groupValue: current,
        onChanged: (_) {
          Navigator.pop(ctx);
          appState.setThemeMode(mode);
        },
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
      case ThemeMode.system: return 'system';
    }
  }

  void _showColorDialog() {
    final appState = context.read<AppState>();
    final presets = [
      {'name': 'Purple', 'color': Colors.purple},
      {'name': 'Blue', 'color': Colors.blue},
      {'name': 'Green', 'color': Colors.green},
      {'name': 'Orange', 'color': Colors.orange},
      {'name': 'Red', 'color': Colors.red},
      {'name': 'Teal', 'color': Colors.teal},
    ];
    final isCustom = !presets.any((e) => (e['color'] as Color).value == appState.accentColor.value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets.map((e) {
                  final c = e['color'] as Color;
                  final sel = c.value == appState.accentColor.value;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      appState.setAccentColor(c);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? Colors.white : Theme.of(context).colorScheme.outline,
                          width: sel ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: sel
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                e['name'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 9),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomColorPicker(appState);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCustom ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                      width: isCustom ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCustom ? appState.accentColor : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
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
      ),
    );
  }

  void _showCustomColorPicker(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomColorPickerDialog(
        initialColor: appState.accentColor,
        onColorSelected: (c) => appState.setAccentColor(c),
      ),
    );
  }

  String _getLanguageNameForLocale(Locale locale) {
    final base = _languageNames[locale.languageCode] ?? locale.languageCode;
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '$base (${locale.countryCode})';
    }
    return base;
  }

  void _showLanguageDialog(AppState appState) {
    final current = appState.locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: ListView(
            children: [
              RadioListTile<Locale?>(
                title: const Text('System default'),
                value: null,
                groupValue: current,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  appState.setLocale(null);
                },
              ),
              const Divider(),
              ...AppLocalizations.supportedLocales.map((locale) => RadioListTile<Locale?>(
                title: Text(_getLanguageNameForLocale(locale)),
                value: locale,
                groupValue: current,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  appState.setLocale(locale);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addLocalDirectory(AppState appState) async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Music Directory');
    if (result == null) return;
    try {
      await appState.mediaServiceManager.addLocalMusicDirectory(result);
      if (mounted) {
        _showNotification('Added directory: ${result.split('/').last}');
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error adding directory: $e', color: Colors.red);
      }
    }
  }

  Future<void> _removeLocalDirectory(AppState appState, String directory) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Directory'),
        content: Text('Remove "${directory.split('/').last}" from your music sources?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await appState.mediaServiceManager.localMusicService?.removeDirectory(directory);
      if (mounted) {
        _showNotification('Directory removed');
        setState(() {});
      }
    }
  }

  Future<void> _rescanLocalLibrary(AppState appState) async {
    final local = appState.mediaServiceManager.localMusicService;
    if (local == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Scanning Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            StreamBuilder<String>(
              stream: Stream.periodic(const Duration(milliseconds: 500), (_) => local.isScanning ? 'Scanning...' : 'Complete'),
              builder: (_, snap) => Text(snap.data ?? 'Starting...'),
            ),
          ],
        ),
      ),
    );
    try {
      await local.scanDirectories();
      if (mounted) {
        Navigator.pop(context);
        _showNotification('Library scan complete');
        await appState.loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showNotification('Scan error: $e', color: Colors.red);
      }
    }
  }

  void _testConnection(AppState appState) {
    _showNotification(
      appState.isLoggedIn ? 'Connection successful!' : 'Connection failed. Please check your settings.',
      color: appState.isLoggedIn ? Colors.green : Colors.red,
    );
  }

  void _showSignOutDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You\'ll need to log in again to access your music.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
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
      builder: (ctx) => AlertDialog(
        title: Text('Clear ${cacheType == 'all' ? 'All' : 'Image'} Cache'),
        content: Text(
          'This will remove ${cacheType == 'all' ? 'all cached data' : 'cached images'} and may slow down the app temporarily. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final appState = context.read<AppState>();
              try {
                if (cacheType == 'all') {
                  await appState.clearAllCache();
                } else {
                  await appState.clearImageCache();
                }
                if (mounted) {
                  _showNotification('${cacheType == 'all' ? 'All' : 'Image'} cache cleared');
                }
              } catch (e) {
                if (mounted) {
                  _showNotification('Failed: $e', color: Colors.red);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// --- Sidebar ---
class _Sidebar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final AppLocalizations l10n;
  final bool isLocalMusic;

  const _Sidebar({required this.selected, required this.onSelect, required this.l10n, required this.isLocalMusic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      {'id': 'audio', 'label': l10n.audioSettings.split(' ').first, 'icon': Icons.volume_up_rounded},
      {'id': 'appearance', 'label': l10n.appearanceSettings.split(' ').first, 'icon': Icons.palette_rounded},
      {'id': 'server', 'label': isLocalMusic ? 'Local' : l10n.server, 'icon': isLocalMusic ? Icons.folder_rounded : Icons.dns_rounded},
      {'id': 'about', 'label': l10n.aboutDoudou.split(' ').first, 'icon': Icons.info_rounded},
    ];
    final filtered = isLocalMusic
        ? categories.where((c) => c['id'] != 'server').toList()
        : categories;

    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filtered.map((c) {
          final id = c['id'] as String;
          final isSelected = selected == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: isSelected ? DesktopTheme.glassOverlay : Colors.transparent,
              borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
              child: InkWell(
                onTap: () => onSelect(id),
                borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingMd, vertical: DesktopTheme.spacingSm + 4),
                  child: Row(
                    children: [
                      Icon(c['icon'] as IconData, size: 20, color: isSelected ? theme.colorScheme.primary : DesktopTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? theme.colorScheme.primary : DesktopTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- Audio ---
class _AudioSection extends StatelessWidget {
  final AppState appState;

  const _AudioSection({required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.sizeOf(context).width < _kSettingsBreakpoint;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? DesktopTheme.spacingMd : DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio Settings', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: isSmall ? 12 : 24),
            SizedBox(
              width: isSmall ? double.infinity : 520,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playback', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: isSmall ? 8 : 12),
                      SwitchListTile(
                        title: const Text('Smart back button'),
                        subtitle: const Text('If past 20%: first back restarts, second back quickly goes to previous track'),
                        value: appState.smartBackToStartEnabled,
                        onChanged: (v) => appState.toggleSmartBackToStart(v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Appearance ---
class _AppearanceSection extends StatelessWidget {
  final AppState appState;
  final VoidCallback onTheme;
  final VoidCallback onColor;
  final VoidCallback onLanguage;

  const _AppearanceSection({required this.appState, required this.onTheme, required this.onColor, required this.onLanguage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isSmall = MediaQuery.sizeOf(context).width < _kSettingsBreakpoint;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? DesktopTheme.spacingMd : DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appearanceSettings, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: isSmall ? 12 : 24),
            SizedBox(
              width: isSmall ? double.infinity : 520,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Look & language', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: isSmall ? 8 : 12),
                      ListTile(
                        title: Text(l10n.appTheme),
                        subtitle: Text(_themeDisplayName(appState.themeMode)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: onTheme,
                      ),
                      ListTile(
                        title: Text(l10n.accentColor),
                        subtitle: Text(_colorDisplayName(appState.accentColor)),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: appState.accentColor, shape: BoxShape.circle),
                        ),
                        onTap: onColor,
                      ),
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(l10n.selectLanguage),
                        subtitle: Text(_languageDisplayName(appState)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: onLanguage,
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('OLED dark mode'),
                        subtitle: const Text('Pure black backgrounds'),
                        value: appState.oledDarkModeEnabled,
                        onChanged: appState.toggleOledDarkMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System default';
    }
  }

  static String _colorDisplayName(Color color) {
    if (color.value == Colors.purple.value) return 'Purple';
    if (color.value == Colors.blue.value) return 'Blue';
    if (color.value == Colors.green.value) return 'Green';
    if (color.value == Colors.orange.value) return 'Orange';
    if (color.value == Colors.red.value) return 'Red';
    if (color.value == Colors.teal.value) return 'Teal';
    return 'Custom (#${color.value.toRadixString(16).substring(2).toUpperCase()})';
  }

  static String _languageDisplayName(AppState appState) {
    final locale = appState.locale;
    if (locale == null) return 'System default';
    return _languageNames[locale.languageCode] ?? locale.languageCode;
  }
}

const Map<String, String> _languageNames = {
  'en': 'English', 'es': 'Español', 'fr': 'Français', 'de': 'Deutsch',
  'it': 'Italiano', 'pt': 'Português', 'ru': 'Русский', 'zh': '中文',
  'ja': '日本語', 'ko': '한국어', 'ar': 'العربية', 'hi': 'हिन्दी',
  'nl': 'Nederlands', 'pl': 'Polski', 'tr': 'Türkçe', 'vi': 'Tiếng Việt',
  'th': 'ไทย', 'id': 'Indonesia', 'uk': 'Українська',
};

// --- Server ---
class _ServerSection extends StatelessWidget {
  final AppState appState;
  final Future<void> Function(AppState) onAddDir;
  final Future<void> Function(AppState, String) onRemoveDir;
  final Future<void> Function(AppState) onRescan;
  final void Function(AppState) onTestConnection;
  final void Function(AppState) onSignOut;
  final void Function(String) onClearCache;
  final void Function(String, {Color? color}) onShowNotification;

  const _ServerSection({
    required this.appState,
    required this.onAddDir,
    required this.onRemoveDir,
    required this.onRescan,
    required this.onTestConnection,
    required this.onSignOut,
    required this.onClearCache,
    required this.onShowNotification,
  });

  /// Get server URL and username from current service or SharedPreferences fallback.
  Future<Map<String, String?>> _getServerInfo(AppState appState) async {
    // Try to get from current service first
    final currentServer = appState.mediaServiceManager.currentService?.currentServer;
    if (currentServer is Map) {
      final url = currentServer['url'] as String?;
      final username = currentServer['username'] as String?;
      if (url != null || username != null) {
        return {'url': url, 'username': username};
      }
    }

    // Fall back to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString('server_url');
      final username = prefs.getString('server_identifier');
      return {'url': serverUrl, 'username': username};
    } catch (_) {
      return {'url': null, 'username': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLocal = appState.mediaServiceManager.currentServerType == ServerType.local;
    final localService = appState.mediaServiceManager.localMusicService;

    final isSmall = MediaQuery.sizeOf(context).width < _kSettingsBreakpoint;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? DesktopTheme.spacingMd : DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLocal ? 'Local Music Settings' : l10n.serverSettings,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: isSmall ? 12 : 24),
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(isLocal ? 'Music Source' : l10n.connection, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: appState.isLoggedIn ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            appState.isLoggedIn ? (isLocal ? 'Active' : l10n.authenticated) : 'Disconnected',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmall ? 12 : 16),
                    ListTile(
                      title: const Text('Refresh library'),
                      subtitle: const Text('Reload albums, artists, and tracks'),
                      leading: const Icon(Icons.refresh_rounded),
                      onTap: () async {
                        await appState.loadLibraryData();
                        if (context.mounted) {
                          onShowNotification('Library refreshed');
                        }
                      },
                    ),
                    const Divider(),
                    if (isLocal && localService != null) ...[
                      ListTile(
                        title: const Text('Music Directories'),
                        subtitle: Text('${localService.musicDirectories.length} folder(s) configured'),
                        trailing: const Icon(Icons.folder),
                      ),
                      ...localService.musicDirectories.map((dir) => ListTile(
                        leading: const Icon(Icons.folder_open, size: 20),
                        title: Text(dir.split('/').last, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(dir, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => onRemoveDir(appState, dir),
                        ),
                      )),
                      const Divider(),
                      ListTile(title: const Text('Add Directory'), leading: const Icon(Icons.create_new_folder), onTap: () => onAddDir(appState)),
                      ListTile(
                        title: const Text('Rescan Library'),
                        leading: const Icon(Icons.refresh),
                        subtitle: const Text('Scan directories for new music'),
                        onTap: () => onRescan(appState),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Fetch Online Artwork'),
                        subtitle: const Text('Download album art from MusicBrainz'),
                        value: localService.fetchOnlineArtwork,
                        onChanged: (v) async {
                          await localService.setFetchOnlineArtwork(v);
                        },
                      ),
                    ] else if (appState.mediaServiceManager.currentServerType == ServerType.soundcloud) ...[
                      ListTile(
                        title: const Text('SoundCloud'),
                        subtitle: const Text('Using your app credentials (Client ID / Client Secret)'),
                        leading: const Icon(Icons.cloud),
                      ),
                      ListTile(
                        title: const Text('Register your app'),
                        subtitle: const Text('developers.soundcloud.com'),
                        leading: const Icon(Icons.link),
                        onTap: () => launchUrl(Uri.parse('https://developers.soundcloud.com')),
                      ),
                    ] else ...[
                      FutureBuilder<Map<String, String?>>(
                        future: _getServerInfo(appState),
                        builder: (context, snapshot) {
                          final serverUrl = snapshot.data?['url'] ?? 'Not set';
                          final username = snapshot.data?['username'] ?? 'Not logged in';
                          return Column(
                            children: [
                              ListTile(
                                title: const Text('Server URL'),
                                subtitle: Text(serverUrl),
                                trailing: const Icon(Icons.edit),
                              ),
                              ListTile(
                                title: const Text('Username'),
                                subtitle: Text(username),
                                trailing: const Icon(Icons.person),
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Test Connection'),
                        leading: const Icon(Icons.wifi_tethering),
                        onTap: () => onTestConnection(appState),
                      ),
                    ],
                    ListTile(
                      title: const Text('Sign Out'),
                      leading: const Icon(Icons.logout),
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () => onSignOut(appState),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isSmall ? 12 : 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cache', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: isSmall ? 12 : 16),
                    ListTile(
                      title: const Text('Clear image cache'),
                      subtitle: const Text('Free up storage space'),
                      trailing: const Icon(Icons.clear),
                      onTap: () => onClearCache('images'),
                    ),
                    if (isLocal && localService != null)
                      ListTile(
                        title: const Text('Clear artwork cache'),
                        subtitle: const Text('Remove downloaded album artwork'),
                        trailing: const Icon(Icons.image_not_supported),
                        onTap: () async {
                          await localService.clearArtworkCache();
                          if (context.mounted) {
                            onShowNotification('Artwork cache cleared');
                          }
                        },
                      ),
                    ListTile(
                      title: const Text('Clear all cache'),
                      subtitle: const Text('Remove all cached data'),
                      trailing: const Icon(Icons.delete_sweep),
                      onTap: () => onClearCache('all'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- About ---
class _AboutSection extends StatelessWidget {
  final AppState appState;

  const _AboutSection({required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.sizeOf(context).width < _kSettingsBreakpoint;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? DesktopTheme.spacingMd : DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About Doudou', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: isSmall ? 12 : 24),
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 16 : 32),
                child: Column(
                  children: [
                    Image.asset('assets/icons/icon.png', width: 80, height: 80, errorBuilder: (_, _, _) => const Icon(Icons.music_note, size: 80)),
                    SizedBox(height: isSmall ? 12 : 24),
                    Text('Doudou', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    SizedBox(height: isSmall ? 12 : 24),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (_, snap) {
                        final v = snap.data?.version ?? 'Unknown';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Version $v', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimaryContainer)),
                        );
                      },
                    ),
                    SizedBox(height: isSmall ? 12 : 16),
                    const Text('A beautiful music player for anyone anywhere.', textAlign: TextAlign.center),
                    SizedBox(height: isSmall ? 12 : 24),
                    _UpdateCheckButton(theme: theme),
                  ],
                ),
              ),
            ),
            SizedBox(height: isSmall ? 12 : 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: isSmall ? 12 : 16),
                    ListTile(title: const Text('Platform'), subtitle: Text(_getPlatformInfo()), leading: const Icon(Icons.computer)),
                    ListTile(title: const Text('Build Date'), subtitle: Text(_getBuildDate()), leading: const Icon(Icons.calendar_today)),
                    ListTile(title: const Text('Operating System'), subtitle: Text(_getOSVersion()), leading: const Icon(Icons.settings_system_daydream)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformInfo() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final r = Process.runSync('uname', ['-m']);
        if (r.exitCode == 0) return '${Platform.operatingSystem} (${r.stdout.toString().trim()})';
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  String _getBuildDate() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _getOSVersion() {
    try {
      if (Platform.isLinux) {
        final r = Process.runSync('lsb_release', ['-d', '-s']);
        if (r.exitCode == 0) return r.stdout.toString().trim().replaceAll('"', '');
        final k = Process.runSync('uname', ['-r']);
        if (k.exitCode == 0) return 'Linux ${k.stdout.toString().trim()}';
      } else if (Platform.isMacOS) {
        final r = Process.runSync('sw_vers', ['-productVersion']);
        if (r.exitCode == 0) return 'macOS ${r.stdout.toString().trim()}';
      }
    } catch (_) {}
    return Platform.operatingSystemVersion;
  }
}

class _UpdateCheckButton extends StatefulWidget {
  final ThemeData theme;

  const _UpdateCheckButton({required this.theme});

  @override
  State<_UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends State<_UpdateCheckButton> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _checking = false);
      if (info.updateAvailable) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Available'),
            content: Text('Current: ${info.currentVersion}\nLatest: ${info.latestVersion}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('https://openlyst.ink/apps/doudou'), mode: LaunchMode.externalApplication);
                },
                child: const Text('View Update'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Up to Date'),
            content: Text('Doudou ${info.currentVersion} is the latest version.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Check Failed'),
            content: const Text('Unable to check for updates. Please try again later.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _checking ? null : _check,
      icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh),
      label: Text(_checking ? 'Checking...' : 'Check for Updates'),
    );
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _CustomColorPickerDialog({required this.initialColor, required this.onColorSelected});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late Color _color;
  late TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _hex = TextEditingController(text: _color.value.toRadixString(16).substring(2).toUpperCase());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _update(Color c) {
    setState(() {
      _color = c;
      _hex.text = c.value.toRadixString(16).substring(2).toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Custom Accent Color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outline)),
              child: Center(
                child: Text(
                  'Preview',
                  style: TextStyle(color: _color.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _slider('Red', _color.red.toDouble(), Colors.red, (v) => _update(Color.fromARGB(255, v.round(), _color.green, _color.blue))),
            _slider('Green', _color.green.toDouble(), Colors.green, (v) => _update(Color.fromARGB(255, _color.red, v.round(), _color.blue))),
            _slider('Blue', _color.blue.toDouble(), Colors.blue, (v) => _update(Color.fromARGB(255, _color.red, _color.green, v.round()))),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Hex: #'),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    maxLength: 6,
                    onChanged: (s) {
                      if (s.length == 6) {
                        try {
                          setState(() => _color = Color(int.parse('FF$s', radix: 16)));
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onColorSelected(_color);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        SizedBox(
          height: 30,
          child: Slider(value: value, min: 0, max: 255, divisions: 255, activeColor: color, onChanged: onChanged),
        ),
      ],
    );
  }
}
