import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/update_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/settings/server_connection_section.dart';

/// Breakpoint: below this width use mobile list → detail; above use sidebar + detail.
const double _kSettingsBreakpoint = 768.0;

/// Menu item for iOS-style settings list.
class _SettingsMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String section;
  final String? Function(AppState)? valueText;

  const _SettingsMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.section,
    this.valueText,
  });
}

/// Settings page: iOS-style grouped list and sub-pages (one content area per item).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// null on mobile = show list; on desktop we default to first item.
  String? _selectedId;

  List<_SettingsMenuItem> _menuItems(AppLocalizations l10n, bool isLocalMusic) {
    final items = <_SettingsMenuItem>[
      _SettingsMenuItem(
        id: 'audio',
        label: l10n.audioSettings,
        icon: Icons.volume_up_rounded,
        iconColor: const Color(0xFFEC4899),
        section: 'Playback',
      ),
      _SettingsMenuItem(
        id: 'appearance',
        label: l10n.appearanceSettings,
        icon: Icons.palette_rounded,
        iconColor: const Color(0xFF8B5CF6),
        section: 'Appearance',
      ),
      _SettingsMenuItem(
        id: 'server',
        label: isLocalMusic ? 'Local Music' : l10n.server,
        icon: isLocalMusic ? Icons.folder_rounded : Icons.dns_rounded,
        iconColor: const Color(0xFF3B82F6),
        section: 'Server',
        valueText: (a) => a.isLoggedIn ? (isLocalMusic ? 'Active' : (a.jellyfinService.username ?? 'Connected')) : null,
      ),
      _SettingsMenuItem(
        id: 'about',
        label: l10n.aboutDoudou,
        icon: Icons.info_rounded,
        iconColor: const Color(0xFF6B7280),
        section: 'About',
      ),
    ];
    if (isLocalMusic) return items.where((e) => e.id != 'server').toList();
    return items;
  }

  static const List<String> _sectionOrder = ['Playback', 'Appearance', 'Server', 'About'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isLocal = appState.mediaServiceManager.currentServerType == ServerType.local;
        final items = _menuItems(l10n, isLocal);
        final sections = _sectionOrder.where((s) => items.any((i) => i.section == s)).toList();
        final isDesktop = MediaQuery.sizeOf(context).width >= _kSettingsBreakpoint;
        // Desktop: default to first item when none selected
        final effectiveSelected = _selectedId ?? (isDesktop ? items.first.id : null);

        return LayoutBuilder(
          builder: (context, constraints) {
            final useSidebar = constraints.maxWidth >= _kSettingsBreakpoint;

            if (useSidebar) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
              return Scaffold(
                backgroundColor: bg,
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsListSidebar(
                      sections: sections,
                      items: items,
                      appState: appState,
                      selectedId: effectiveSelected,
                      onSelect: (id) => setState(() => _selectedId = id),
                    ),
                    Expanded(
                      child: Container(
                        color: bg,
                        child: effectiveSelected != null
                            ? _buildDetailContent(context, appState, effectiveSelected)
                            : const Center(child: Text('Select a setting')),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile: list or detail with back
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final mobileBg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
            final mobileTitleColor = isDark ? Colors.white : Colors.black;

            if (effectiveSelected == null) {
              return Scaffold(
                backgroundColor: mobileBg,
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Text(
                          l10n.settings,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: mobileTitleColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _SettingsListMobile(
                          sections: sections,
                          items: items,
                          appState: appState,
                          onSelect: (id) => setState(() => _selectedId = id),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              backgroundColor: mobileBg,
              appBar: AppBar(
                title: Text(
                  items.firstWhere((e) => e.id == effectiveSelected, orElse: () => items.first).label,
                  style: TextStyle(color: mobileTitleColor, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: () => setState(() => _selectedId = null),
                ),
                backgroundColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                foregroundColor: mobileTitleColor,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              body: _buildDetailContent(context, appState, effectiveSelected),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailContent(BuildContext context, AppState appState, String id) {
    switch (id) {
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
        );
      case 'about':
        return _AboutSection(appState: appState);
      default:
        return _AppearanceSection(
          appState: appState,
          onTheme: _showThemeDialog,
          onColor: _showColorDialog,
          onLanguage: () => _showLanguageDialog(appState),
        );
    }
  }

  String _effectiveThemeSelection(AppState appState) {
    if (appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled) {
      return 'oled';
    }
    switch (appState.themeMode) {
      case ThemeMode.system: return 'system';
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
    }
  }

  void _showThemeDialog() {
    final appState = context.read<AppState>();
    final current = _effectiveThemeSelection(appState);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeRadio(ctx, appState, 'system', current, 'System Default', () {
              Navigator.pop(ctx);
              appState.setThemeMode(ThemeMode.system);
              appState.toggleOledDarkMode(false);
            }),
            _themeRadio(ctx, appState, 'light', current, 'Light', () {
              Navigator.pop(ctx);
              appState.setThemeMode(ThemeMode.light);
              appState.toggleOledDarkMode(false);
            }),
            _themeRadio(ctx, appState, 'dark', current, 'Dark', () {
              Navigator.pop(ctx);
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(false);
            }),
            _themeRadio(ctx, appState, 'oled', current, 'OLED', () {
              Navigator.pop(ctx);
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _themeRadio(BuildContext ctx, AppState appState, String value, String groupValue, String label, VoidCallback onSelect) {
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (_) => onSelect(),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added directory: ${result.split('/').last}')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding directory: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Directory removed')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Library scan complete')));
        await appState.loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
    }
  }

  void _testConnection(AppState appState) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appState.isLoggedIn ? 'Connection successful!' : 'Connection failed. Please check your settings.'),
        backgroundColor: appState.isLoggedIn ? Colors.green : Colors.red,
      ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${cacheType == 'all' ? 'All' : 'Image'} cache cleared')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

// --- iOS-style list: sidebar (desktop) ---
class _SettingsListSidebar extends StatelessWidget {
  final List<String> sections;
  final List<_SettingsMenuItem> items;
  final AppState appState;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _SettingsListSidebar({
    required this.sections,
    required this.items,
    required this.appState,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);
    return Container(
      width: 280,
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sections.map((section) {
                  final sectionItems = items.where((i) => i.section == section).toList();
                  if (sectionItems.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 6),
                          child: Text(
                            section.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                        Material(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            children: sectionItems.asMap().entries.map((e) {
                              final item = e.value;
                              final isSelected = selectedId == item.id;
                              final value = item.valueText?.call(appState);
                              return InkWell(
                                onTap: () => onSelect(item.id),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white24 : item.iconColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(item.icon, size: 16, color: Colors.white),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (value != null && value.isNotEmpty)
                                        Text(
                                          value,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- iOS-style list: full list (mobile) ---
class _SettingsListMobile extends StatelessWidget {
  final List<String> sections;
  final List<_SettingsMenuItem> items;
  final AppState appState;
  final ValueChanged<String> onSelect;

  const _SettingsListMobile({
    required this.sections,
    required this.items,
    required this.appState,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: sections.length,
      itemBuilder: (context, idx) {
        final section = sections[idx];
        final sectionItems = items.where((i) => i.section == section).toList();
        if (sectionItems.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  section.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              Material(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: sectionItems.map((item) {
                    final value = item.valueText?.call(appState);
                    return InkWell(
                      onTap: () => onSelect(item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: item.iconColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(item.icon, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (value != null && value.isNotEmpty)
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio Settings', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playback', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appearanceSettings, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Look & language', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(l10n.appTheme),
                        subtitle: Text(_themeDisplayName(appState)),
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

  static String _themeDisplayName(AppState appState) {
    if (appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled) {
      return 'OLED';
    }
    switch (appState.themeMode) {
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

  const _ServerSection({
    required this.appState,
    required this.onAddDir,
    required this.onRemoveDir,
    required this.onRescan,
    required this.onTestConnection,
    required this.onSignOut,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLocal = appState.mediaServiceManager.currentServerType == ServerType.local;
    final localService = appState.mediaServiceManager.localMusicService;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLocal ? 'Local Music Settings' : l10n.serverSettings,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 16),
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
                    ] else ...[
                      ListTile(
                        title: const Text('Server URL'),
                        subtitle: Text(appState.jellyfinService.serverUrl ?? 'Not set'),
                        trailing: const Icon(Icons.edit),
                      ),
                      ListTile(
                        title: const Text('Username'),
                        subtitle: Text(
                          appState.jellyfinService.username?.trim().isNotEmpty == true
                              ? appState.jellyfinService.username!
                              : (appState.isLoggedIn ? 'Logged in' : 'Not logged in'),
                        ),
                        trailing: const Icon(Icons.person),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Test Connection'),
                        leading: const Icon(Icons.wifi_tethering),
                        onTap: () => onTestConnection(appState),
                      ),
                    ],
                    ListTile(
                      title: const Text('Disconnect'),
                      leading: const Icon(Icons.link_off_rounded),
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () => onSignOut(appState),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.isLoggedIn ? 'Switch server' : 'Connect to a server',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    const ServerConnectionSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cache', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
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
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artwork cache cleared')));
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About Doudou', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Image.asset('assets/icons/icon.png', width: 80, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 80)),
                    const SizedBox(height: 24),
                    Text('Doudou', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 16),
                    const Text('A beautiful music player for anyone anywhere.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    _UpdateCheckButton(theme: theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
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
