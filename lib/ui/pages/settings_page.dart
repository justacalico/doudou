import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/update_service.dart';

import 'package:doudou/models/saved_server.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/settings/server_connection_section.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';

/// Breakpoint: below this width use mobile list → detail; above use sidebar + detail.
const double _kSettingsBreakpoint = 768.0;

String _settingsSectionLabel(AppLocalizations l10n, String section) {
  switch (section) {
    case 'Server':
      return l10n.server;
    case 'General':
      return l10n.general;
    case 'Playback':
      return l10n.playback;
    case 'Appearance':
      return l10n.appearance;
    case 'About':
      return l10n.about;
    default:
      return section;
  }
}

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
  late final bool _autoCloseWhenConnected;
  bool _didAutoClose = false;

  @override
  void initState() {
    super.initState();
    // When settings is opened from the "No server connected" screen, close it
    // automatically after a successful login so app shell navigation is visible.
    _autoCloseWhenConnected = !context.read<AppState>().isLoggedIn;
  }

  List<_SettingsMenuItem> _menuItems(AppLocalizations l10n, bool isLocalMusic) {
    final items = <_SettingsMenuItem>[
      _SettingsMenuItem(
        id: 'server',
        label: isLocalMusic ? l10n.localMusic : l10n.server,
        icon: isLocalMusic ? Icons.folder_rounded : Icons.dns_rounded,
        iconColor: const Color(0xFF3B82F6),
        section: 'Server',
        valueText: (a) => a.isLoggedIn
            ? (isLocalMusic
                  ? l10n.active
                  : (a.jellyfinService.username ?? l10n.connected))
            : null,
      ),
      _SettingsMenuItem(
        id: 'general',
        label: l10n.generalSettings,
        icon: Icons.tune_rounded,
        iconColor: const Color(0xFF10B981),
        section: 'General',
        valueText: null,
      ),
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
        iconColor: const Color(0xFF38BDF8),
        section: 'Appearance',
      ),
      _SettingsMenuItem(
        id: 'about',
        label: l10n.aboutDoudou,
        icon: Icons.info_rounded,
        iconColor: const Color(0xFF6B7280),
        section: 'About',
      ),
    ];
    return items;
  }

  static const List<String> _sectionOrder = [
    'Server',
    'General',
    'Playback',
    'Appearance',
    'About',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (_autoCloseWhenConnected &&
            !_didAutoClose &&
            appState.isLoggedIn &&
            Navigator.of(context).canPop()) {
          _didAutoClose = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }

        final isLocal =
            appState.mediaServiceManager.currentServerType == ServerType.local;
        final items = _menuItems(l10n, isLocal);
        final sections = _sectionOrder
            .where((s) => items.any((i) => i.section == s))
            .toList();
        final isDesktop =
            MediaQuery.sizeOf(context).width >= _kSettingsBreakpoint;
        // Desktop: default to first item when none selected
        final effectiveSelected =
            _selectedId ?? (isDesktop ? items.first.id : null);

        return LayoutBuilder(
          builder: (context, constraints) {
            final useSidebar = constraints.maxWidth >= _kSettingsBreakpoint;

            if (useSidebar) {
              final theme = Theme.of(context);
              final bg = theme.scaffoldBackgroundColor;
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
                        color: DesktopTheme.backgroundTertiary,
                        child: effectiveSelected != null
                            ? _buildDetailContent(
                                context,
                                appState,
                                effectiveSelected,
                              )
                            : Center(child: Text(l10n.selectASetting)),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile: list or detail with back
            final theme = Theme.of(context);
            final mobileBg = theme.scaffoldBackgroundColor;
            final mobileTitleColor = theme.colorScheme.onSurface;

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
                  items
                      .firstWhere(
                        (e) => e.id == effectiveSelected,
                        orElse: () => items.first,
                      )
                      .label,
                  style: TextStyle(
                    color: mobileTitleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: () => setState(() => _selectedId = null),
                ),
                backgroundColor:
                    theme.appBarTheme.backgroundColor ??
                    theme.colorScheme.surface,
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

  Widget _buildDetailContent(
    BuildContext context,
    AppState appState,
    String id,
  ) {
    switch (id) {
      case 'general':
        return _GeneralSection(appState: appState);
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
          onSignOut: _showSignOutDialog,
          onClearCache: _showClearCacheDialog,
        );
      case 'about':
        return _AboutSection(appState: appState);
      default:
        return _GeneralSection(appState: appState);
    }
  }

  String _effectiveThemeSelection(AppState appState) {
    if (appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled) {
      return 'oled';
    }
    switch (appState.themeMode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  void _showThemeDialog() {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final current = _effectiveThemeSelection(appState);
    showAppDialog(
      context: context,
      title: l10n.chooseTheme,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogOption(
            label: l10n.systemDefault,
            selected: current == 'system',
            onTap: () {
              Navigator.pop(context);
              appState.setThemeMode(ThemeMode.system);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: l10n.light,
            selected: current == 'light',
            onTap: () {
              Navigator.pop(context);
              appState.setThemeMode(ThemeMode.light);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: l10n.dark,
            selected: current == 'dark',
            onTap: () {
              Navigator.pop(context);
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: l10n.oled,
            selected: current == 'oled',
            onTap: () {
              Navigator.pop(context);
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(true);
            },
          ),
        ],
      ),
    );
  }

  void _showColorDialog() {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    showAppDialog(
      context: context,
      title: l10n.chooseAccentColor,
      content: _AccentColorDialog(
        currentColor: appState.accentColor,
        onColorSelected: (c) {
          Navigator.pop(context);
          appState.setAccentColor(c);
        },
        onCustomTap: () {
          Navigator.pop(context);
          _showCustomColorPicker(appState);
        },
        customLabel: l10n.customColor,
      ),
    );
  }

  void _showCustomColorPicker(AppState appState) {
    final l10n = AppLocalizations.of(context);
    showAppDialog(
      context: context,
      title: l10n.customColor,
      width: 320,
      content: _CustomColorPickerDialog(
        initialColor: appState.accentColor,
        showHexControls: appState.showHexColorControls,
        onColorSelected: (c) {
          appState.setAccentColor(c);
          Navigator.pop(context);
        },
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
    final l10n = AppLocalizations.of(context);
    showAppDialog(
      context: context,
      title: l10n.selectLanguage,
      width: 320,
      maxHeight: 440,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogOption(
            label: l10n.systemDefault,
            selected: current == null,
            onTap: () {
              Navigator.pop(context);
              appState.setLocale(null);
            },
          ),
          ...AppLocalizations.supportedLocales.map(
            (locale) => AppDialogOption(
              label: _getLanguageNameForLocale(locale),
              selected: current == locale,
              onTap: () {
                Navigator.pop(context);
                appState.setLocale(locale);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addLocalDirectory(AppState appState) async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.selectMusicDirectory,
    );
    if (result == null) return;
    try {
      await appState.mediaServiceManager.addLocalMusicDirectory(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addedDirectory(result.split('/').last))),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorAddingDirectory(e.toString()))),
        );
      }
    }
  }

  Future<void> _removeLocalDirectory(
    AppState appState,
    String directory,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.removeDirectoryTitle,
      message: l10n.removeDirectoryMessage(directory.split('/').last),
      confirmLabel: l10n.remove,
      isDestructive: true,
    );
    if (ok == true) {
      await appState.mediaServiceManager.localMusicService?.removeDirectory(
        directory,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.directoryRemoved)));
        setState(() {});
      }
    }
  }

  Future<void> _rescanLocalLibrary(AppState appState) async {
    final l10n = AppLocalizations.of(context);
    final local = appState.mediaServiceManager.localMusicService;
    if (local == null) return;
    showAppDialog(
      context: context,
      title: l10n.scanningLibrary,
      barrierDismissible: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          StreamBuilder<String>(
            stream: Stream.periodic(
              const Duration(milliseconds: 500),
              (_) => local.isScanning ? l10n.scanning : l10n.complete,
            ),
            builder: (_, snap) => Text(
              snap.data ?? l10n.starting,
              style: TextStyle(
                color: DesktopTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
    try {
      await local.scanDirectories();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.libraryScanComplete)));
        await appState.loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.scanError(e.toString()))));
      }
    }
  }

  void _showSignOutDialog(AppState appState) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.signOut,
      message: l10n.signOutConfirmMessage,
      confirmLabel: l10n.signOut,
      isDestructive: true,
    );
    if (ok == true) {
      appState.logout();
    }
  }

  void _showClearCacheDialog(String cacheType) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showAppConfirmDialog(
      context: context,
      title: cacheType == 'all'
          ? l10n.cacheClearedTitle('All')
          : l10n.cacheClearedTitle('Image'),
      message: l10n.clearCacheConfirm(
        cacheType == 'all' ? l10n.allCachedData : l10n.cachedImages,
      ),
      confirmLabel: l10n.clear,
      isDestructive: true,
    );
    if (ok == true) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      try {
        if (cacheType == 'all') {
          await appState.clearAllCache();
        } else {
          await appState.clearImageCache();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.cacheCleared(
                  cacheType == 'all' ? l10n.allCachedData : l10n.cachedImages,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
          );
        }
      }
    }
  }
}

// --- Settings sidebar (desktop, Gemini-style) ---
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundPrimary,
        border: Border(
          right: BorderSide(color: DesktopTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.settings,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: DesktopTheme.textPrimary,
                    ),
                  ),
                ),
                if (Navigator.of(context).canPop())
                  IconButton(
                    tooltip: l10n.close,
                    icon: const Icon(Icons.close_rounded),
                    color: DesktopTheme.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sections.map((section) {
                  final sectionItems = items
                      .where((i) => i.section == section)
                      .toList();
                  if (sectionItems.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            _settingsSectionLabel(l10n, section).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: DesktopTheme.textTertiary,
                            ),
                          ),
                        ),
                        ...sectionItems.map(
                          (item) => _SettingsSidebarTile(
                            item: item,
                            isSelected: selectedId == item.id,
                            value: item.valueText?.call(appState),
                            onTap: () => onSelect(item.id),
                            isDark: isDark,
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

class _SettingsSidebarTile extends StatefulWidget {
  final _SettingsMenuItem item;
  final bool isSelected;
  final String? value;
  final VoidCallback onTap;
  final bool isDark;

  const _SettingsSidebarTile({
    required this.item,
    required this.isSelected,
    required this.value,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_SettingsSidebarTile> createState() => _SettingsSidebarTileState();
}

class _SettingsSidebarTileState extends State<_SettingsSidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: widget.isSelected || _hover
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.item.iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 20,
                    color: widget.item.iconColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isSelected
                              ? DesktopTheme.textPrimary
                              : DesktopTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _settingsSectionLabel(l10n, widget.item.section),
                        style: TextStyle(
                          fontSize: 11,
                          color: DesktopTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.value != null && widget.value!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      widget.value!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade400,
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: widget.isSelected
                      ? DesktopTheme.textPrimary
                      : DesktopTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final headerColor = DesktopTheme.textSecondary;
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
                  _settingsSectionLabel(l10n, section).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: headerColor,
                  ),
                ),
              ),
              Material(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: sectionItems.map((item) {
                    final value = item.valueText?.call(appState);
                    return InkWell(
                      onTap: () => onSelect(item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: item.iconColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.icon,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (value != null && value.isNotEmpty)
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
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

class _SettingsPanel extends StatelessWidget {
  final Widget child;

  const _SettingsPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
        border: Border.all(color: DesktopTheme.glassBorder),
        color: DesktopTheme.backgroundSecondary.withValues(alpha: 0.95),
        boxShadow: DesktopTheme.shadowSm,
      ),
      child: child,
    );
  }
}

// --- General ---
class _GeneralSection extends StatelessWidget {
  final AppState appState;

  const _GeneralSection({required this.appState});

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
            Text(
              l10n.generalSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.generalSectionSubtitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(l10n.settingsLyrics),
                      subtitle: Text(l10n.settingsLyricsDescription),
                      value: appState.lyricsEnabled,
                      onChanged: (v) => appState.setLyricsEnabled(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.settingsDownloads),
                      subtitle: Text(l10n.settingsDownloadsDescription),
                      value: appState.downloadsEnabled,
                      onChanged: (v) => appState.setDownloadsEnabled(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.settingsVolumeOnPlayerBar),
                      subtitle: Text(
                        l10n.settingsVolumeOnPlayerBarDescription,
                      ),
                      value: appState.showVolumeOnPlayerBar,
                      onChanged: (v) => appState.setShowVolumeOnPlayerBar(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.settingsQueueOnPlayerBar),
                      subtitle: Text(
                        l10n.settingsQueueOnPlayerBarDescription,
                      ),
                      value: appState.showQueueOnPlayerBar,
                      onChanged: (v) => appState.setShowQueueOnPlayerBar(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.settingsShuffleRepeatOnPlayerBar),
                      subtitle: Text(
                        l10n.settingsShuffleRepeatOnPlayerBarDescription,
                      ),
                      value: appState.showShuffleRepeatOnPlayerBar,
                      onChanged: (v) =>
                          appState.setShowShuffleRepeatOnPlayerBar(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.showHexColorControls),
                      subtitle: Text(l10n.showHexColorControlsDescription),
                      value: appState.showHexColorControls,
                      onChanged: (v) => appState.setShowHexColorControls(v),
                    ),
                    if (appState.isDesktopWhereYoutubeMusicRestricted)
                      SwitchListTile(
                        title: Text(l10n.settingsYoutubeMusicOnDesktop),
                        subtitle: Text(
                          l10n.settingsYoutubeMusicOnDesktopDescription,
                        ),
                        value: appState.allowYoutubeMusicOnDesktop,
                        onChanged: (v) =>
                            appState.setAllowYoutubeMusicOnDesktop(v),
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

// --- Audio ---
class _AudioSection extends StatefulWidget {
  final AppState appState;

  const _AudioSection({required this.appState});

  @override
  State<_AudioSection> createState() => _AudioSectionState();
}

class _AudioSectionState extends State<_AudioSection> {
  late double _volume;
  late double _speed;

  @override
  void initState() {
    super.initState();
    _volume = widget.appState.audioDefaultVolume;
    _speed = widget.appState.audioDefaultSpeed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final appState = widget.appState;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.audioSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.playback,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(l10n.smartBackButton),
                      subtitle: Text(l10n.smartBackButtonDescription),
                      value: appState.smartBackToStartEnabled,
                      onChanged: (v) => appState.toggleSmartBackToStart(v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.defaultVolumeLabel((_volume * 100).round()),
                      ),
                      subtitle: Text(l10n.defaultVolumeDescription),
                    ),
                    Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '${(_volume * 100).round()}%',
                      onChanged: (v) => setState(() => _volume = v),
                      onChangeEnd: (v) => appState.setAudioDefaultVolume(v),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.defaultSpeedLabel(_speed.toStringAsFixed(2)),
                      ),
                      subtitle: Text(l10n.defaultSpeedDescription),
                    ),
                    Slider(
                      value: _speed,
                      min: 0.5,
                      max: 1.5,
                      divisions: 20,
                      label: '${_speed.toStringAsFixed(2)}x',
                      onChanged: (v) => setState(() => _speed = v),
                      onChangeEnd: (v) => appState.setAudioDefaultSpeed(v),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l10n.gaplessPlayback),
                      subtitle: Text(l10n.seamlessTransitions),
                      value: appState.gaplessPlaybackEnabled,
                      onChanged: (v) =>
                          appState.setGaplessPlaybackEnabled(v),
                    ),
                    SwitchListTile(
                      title: Text(l10n.autoplay),
                      subtitle: Text(l10n.autoplayDescription),
                      value: appState.autoplayRecommendationsEnabled,
                      onChanged: (v) =>
                          appState.setAutoplayRecommendationsEnabled(v),
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

// --- Appearance ---
class _AppearanceSection extends StatelessWidget {
  final AppState appState;
  final VoidCallback onTheme;
  final VoidCallback onColor;
  final VoidCallback onLanguage;

  const _AppearanceSection({
    required this.appState,
    required this.onTheme,
    required this.onColor,
    required this.onLanguage,
  });

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
            Text(
              l10n.appearanceSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lookAndLanguage,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(l10n.appTheme),
                      subtitle: Text(_themeDisplayName(context, appState)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: onTheme,
                    ),
                    ListTile(
                      title: Text(l10n.accentColor),
                      subtitle: Text(
                        _colorDisplayName(context, appState.accentColor),
                      ),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: appState.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: onColor,
                    ),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(l10n.selectLanguage),
                      subtitle: Text(_languageDisplayName(context, appState)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: onLanguage,
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_iphone),
                      title: Text(l10n.mobileNavigationStyle),
                      subtitle: Text(
                        appState.useFloatingMobileNav
                            ? l10n.mobileNavFloating
                            : l10n.mobileNavSolid,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showMobileNavStyleDialog(context),
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

  static String _themeDisplayName(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    if (appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled) {
      return l10n.oled;
    }
    switch (appState.themeMode) {
      case ThemeMode.light:
        return l10n.light;
      case ThemeMode.dark:
        return l10n.dark;
      case ThemeMode.system:
        return l10n.systemDefault;
    }
  }

  static String _colorDisplayName(BuildContext context, Color color) {
    final l10n = AppLocalizations.of(context);
    if (color.toARGB32() == const Color(0xFF8EC5FC).toARGB32()) {
      return l10n.colorBabyBlue;
    }
    if (color.toARGB32() == const Color(0xFFB39DDB).toARGB32()) {
      return l10n.colorLavender;
    }
    if (color.toARGB32() == const Color(0xFFA8E6CF).toARGB32()) {
      return l10n.colorMint;
    }
    if (color.toARGB32() == const Color(0xFFFFD3B6).toARGB32()) {
      return l10n.colorPeach;
    }
    if (color.toARGB32() == const Color(0xFFFFA8C5).toARGB32()) {
      return l10n.colorBlush;
    }
    if (color.toARGB32() == const Color(0xFFFFE08A).toARGB32()) {
      return l10n.colorButter;
    }
    return l10n.customColorHex(
      color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  static String _languageDisplayName(BuildContext context, AppState appState) {
    final locale = appState.locale;
    if (locale == null) return AppLocalizations.of(context).systemDefault;
    return _languageNames[locale.languageCode] ?? locale.languageCode;
  }

  void _showMobileNavStyleDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final useFloating = appState.useFloatingMobileNav;

    showAppDialog(
      context: context,
      title: l10n.mobileNavigationStyle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogOption(
            label: l10n.mobileNavSolid,
            selected: !useFloating,
            onTap: () {
              Navigator.pop(context);
              appState.setUseFloatingMobileNav(false);
            },
          ),
          AppDialogOption(
            label: l10n.mobileNavFloating,
            selected: useFloating,
            onTap: () {
              Navigator.pop(context);
              appState.setUseFloatingMobileNav(true);
            },
          ),
        ],
      ),
    );
  }
}

const Map<String, String> _languageNames = {
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
  'uk': 'Українська',
};

// --- Server ---

void _showServerConnectionDialog(
  BuildContext context,
  AppState appState, {
  SavedServer? initialServer,
}) {
  final l10n = AppLocalizations.of(context);
  showAppDialog(
    context: context,
    title: initialServer != null ? l10n.editServer : l10n.addServer,
    width: 420,
    content: ServerConnectionSection(
      initialServer: initialServer,
      onConnectSuccess: (server) async {
        await appState.setCurrentServerAndSave(server);
      },
    ),
    actionsBuilder: (dialogContext) => [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: Text(l10n.cancel),
      ),
    ],
  );
}

class _ServerSection extends StatefulWidget {
  final AppState appState;
  final Future<void> Function(AppState) onAddDir;
  final Future<void> Function(AppState, String) onRemoveDir;
  final Future<void> Function(AppState) onRescan;
  final void Function(AppState) onSignOut;
  final void Function(String) onClearCache;

  const _ServerSection({
    required this.appState,
    required this.onAddDir,
    required this.onRemoveDir,
    required this.onRescan,
    required this.onSignOut,
    required this.onClearCache,
  });

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  String? _switchingServerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final appState = widget.appState;
    final serverType = appState.mediaServiceManager.currentServerType;
    final isLocal = serverType == ServerType.local;
    final localService = appState.mediaServiceManager.localMusicService;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLocal ? l10n.localMusicSettings : l10n.serverSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.servers,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (appState.savedServers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.noServersYetAddOne,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ...appState.savedServers
                        .where(
                          (server) =>
                              !appState.isDesktopWhereYoutubeMusicRestricted ||
                              appState.allowYoutubeMusicOnDesktop ||
                              server.serverType != 'youtubeMusic',
                        )
                        .map((server) {
                          final isCurrent =
                              appState.currentServerId == server.id;
                          final isSwitching = _switchingServerId == server.id;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                server.displayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${server.serverType} • ${server.serverUrl.replaceFirst(RegExp(r'^https?://'), '').split('/').first}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: isCurrent
                                        ? const SizedBox(
                                            key: ValueKey('switch-current'),
                                          )
                                        : isSwitching
                                        ? const SizedBox(
                                            key: ValueKey('switch-loading'),
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : TextButton(
                                            key: ValueKey(
                                              'switch-${server.id}',
                                            ),
                                            onPressed: () async {
                                              setState(
                                                () => _switchingServerId =
                                                    server.id,
                                              );
                                              final ok = await appState
                                                  .switchToServer(server.id);
                                              if (mounted) {
                                                setState(
                                                  () =>
                                                      _switchingServerId = null,
                                                );
                                              }
                                              if (context.mounted &&
                                                  !ok &&
                                                  appState.errorMessage !=
                                                      null) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      appState.errorMessage!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(l10n.switchServer),
                                          ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: _switchingServerId == null
                                        ? () => _showServerConnectionDialog(
                                            context,
                                            appState,
                                            initialServer: server,
                                          )
                                        : null,
                                    tooltip: l10n.editServer,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: _switchingServerId == null
                                        ? () async {
                                            final confirm =
                                                await showAppConfirmDialog(
                                                  context: context,
                                                  title: l10n.removeServerTitle,
                                                  message: l10n
                                                      .removeServerMessage(
                                                        server.displayLabel,
                                                      ),
                                                  confirmLabel: l10n.remove,
                                                  isDestructive: true,
                                                );
                                            if (confirm == true &&
                                                context.mounted) {
                                              await appState.removeServer(
                                                server.id,
                                              );
                                            }
                                          }
                                        : null,
                                    tooltip: l10n.remove,
                                  ),
                                ],
                              ),
                              leading: SizedBox(
                                width: 22,
                                height: 22,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  child: isSwitching
                                      ? const SizedBox(
                                          key: ValueKey('leading-loading'),
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : isCurrent
                                      ? const Icon(
                                          Icons.check_circle,
                                          key: ValueKey('leading-current'),
                                          color: Colors.green,
                                          size: 22,
                                        )
                                      : const SizedBox(
                                          key: ValueKey('leading-empty'),
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showServerConnectionDialog(context, appState),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addServer),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cache,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(l10n.clearImageCache),
                      subtitle: Text(l10n.freeUpStorage),
                      trailing: const Icon(Icons.clear),
                      onTap: () => widget.onClearCache('images'),
                    ),
                    if (isLocal && localService != null)
                      ListTile(
                        title: Text(l10n.clearArtworkCache),
                        subtitle: Text(l10n.removeDownloadedAlbumArtwork),
                        trailing: const Icon(Icons.image_not_supported),
                        onTap: () async {
                          await localService.clearArtworkCache();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.artworkCacheCleared)),
                            );
                          }
                        },
                      ),
                    ListTile(
                      title: Text(l10n.clearAllCache),
                      subtitle: Text(l10n.removeAllCachedData),
                      trailing: const Icon(Icons.delete_sweep),
                      onTap: () => widget.onClearCache('all'),
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.aboutDoudou,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icons/icon.png',
                      width: 80,
                      height: 80,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.music_note, size: 80),
                    ),
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
                      builder: (_, snap) {
                        final v = snap.data?.version ?? 'Unknown';
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
                            l10n.version(v),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.beautifulMusicPlayer,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _UpdateCheckButton(theme: theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.systemInformation,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(l10n.platform),
                      subtitle: Text(_getPlatformInfo()),
                      leading: const Icon(Icons.computer),
                    ),
                    ListTile(
                      title: Text(l10n.buildDate),
                      subtitle: Text(_getBuildDate()),
                      leading: const Icon(Icons.calendar_today),
                    ),
                    ListTile(
                      title: Text(l10n.operatingSystem),
                      subtitle: Text(_getOSVersion()),
                      leading: const Icon(Icons.settings_system_daydream),
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

  String _getPlatformInfo() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final r = Process.runSync('uname', ['-m']);
        if (r.exitCode == 0) {
          return '${Platform.operatingSystem} (${r.stdout.toString().trim()})';
        }
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  String _getBuildDate() {
    final n = DateTime.now();
    return '${n.year}/${n.month.toString().padLeft(2, '0')}/${n.day.toString().padLeft(2, '0')}';
  }

  String _getOSVersion() {
    try {
      if (Platform.isLinux) {
        final r = Process.runSync('lsb_release', ['-d', '-s']);
        if (r.exitCode == 0) {
          return r.stdout.toString().trim().replaceAll('"', '');
        }
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
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _checking = false);
      if (info.updateAvailable) {
        showAppDialog(
          context: context,
          title: l10n.updateAvailableTitle,
          content: Text(
            l10n.updateAvailableMessage(
              info.currentVersion,
              info.latestVersion,
            ),
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                launchUrl(
                  Uri.parse('https://openlyst.ink/apps/doudou'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(l10n.viewUpdate),
            ),
          ],
        );
      } else {
        showAppDialog(
          context: context,
          title: l10n.upToDateTitle,
          content: Text(
            l10n.upToDateMessage(info.currentVersion),
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
        showAppDialog(
          context: context,
          title: l10n.updateCheckFailedTitle,
          content: Text(
            l10n.updateCheckFailedMessage,
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: _checking ? null : _check,
      icon: _checking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh),
      label: Text(_checking ? l10n.checkingUpdates : l10n.checkForUpdates),
    );
  }
}

/// Preset accent colors for the accent color picker.
const List<({String name, Color color})> _kAccentPresets = [
  (name: 'Baby Blue', color: Color(0xFF8EC5FC)),
  (name: 'Lavender', color: Color(0xFFB39DDB)),
  (name: 'Mint', color: Color(0xFFA8E6CF)),
  (name: 'Peach', color: Color(0xFFFFD3B6)),
  (name: 'Blush', color: Color(0xFFFFA8C5)),
  (name: 'Butter', color: Color(0xFFFFE08A)),
];

class _AccentColorDialog extends StatelessWidget {
  const _AccentColorDialog({
    required this.currentColor,
    required this.onColorSelected,
    required this.onCustomTap,
    required this.customLabel,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomTap;
  final String customLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const swatchSize = 52.0;
    const spacing = 16.0;
    const ringWidth = 2.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preset grid: 3x2 circular swatches
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1,
          children: _kAccentPresets.map((preset) {
            final selected = preset.color.toARGB32() == currentColor.toARGB32();
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onColorSelected(preset.color),
                borderRadius: BorderRadius.circular(swatchSize / 2 + ringWidth),
                child: Center(
                  child: Container(
                    width: swatchSize,
                    height: swatchSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: preset.color,
                      border: Border.all(
                        color: selected
                            ? (isDark
                                  ? Colors.white
                                  : theme.colorScheme.primary)
                            : theme.colorScheme.outline.withValues(alpha: 0.5),
                        width: selected ? ringWidth : 1,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color:
                                (isDark
                                        ? Colors.white
                                        : theme.colorScheme.primary)
                                    .withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                      ],
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: preset.color.computeLuminance() > 0.4
                                ? Colors.black87
                                : Colors.white,
                            size: 26,
                          )
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: spacing + 4),
        // Custom color row
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCustomTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentColor,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    customLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  const _CustomColorPickerDialog({
    required this.initialColor,
    required this.showHexControls,
    required this.onColorSelected,
  });

  final Color initialColor;
  final bool showHexControls;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late Color _color;
  late HSVColor _hsv;
  late TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _hsv = HSVColor.fromColor(_color);
    _hex = TextEditingController(
      text: _color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _update(Color c) {
    setState(() {
      _color = c;
      _hsv = HSVColor.fromColor(c);
      _syncHex(c);
    });
  }

  void _updateFromHsv(HSVColor hsv) {
    final c = hsv.toColor();
    setState(() {
      _hsv = hsv;
      _color = c;
      _syncHex(c);
    });
  }

  void _syncHex(Color color) {
    _hex.text = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  }

  void _applyHex(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    if (normalized.length != 6) return;
    try {
      final parsed = Color(int.parse('FF$normalized', radix: 16));
      _update(parsed);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = _color.computeLuminance() > 0.4
        ? Colors.black87
        : Colors.white;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: widget.showHexControls
                  ? Text(
                      '#${_hex.text.toUpperCase()}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: _ColorWheelPicker(hsv: _hsv, onChanged: _updateFromHsv),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Brightness: ${(_hsv.value * 100).round()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: _hsv.value,
            min: 0,
            max: 1,
            onChanged: (v) => _updateFromHsv(_hsv.withValue(v)),
          ),
          if (widget.showHexControls) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _hex,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).hex,
                prefixText: '# ',
                border: const OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
              onChanged: _applyHex,
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => widget.onColorSelected(_color),
                child: Text(AppLocalizations.of(context).save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorWheelPicker extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _ColorWheelPicker({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (d) => _handlePointer(d.localPosition, size),
          onPanUpdate: (d) => _handlePointer(d.localPosition, size),
          child: CustomPaint(
            size: Size.square(size),
            painter: _ColorWheelPainter(hsv: hsv),
          ),
        );
      },
    );
  }

  void _handlePointer(Offset local, double size) {
    final center = Offset(size / 2, size / 2);
    final delta = local - center;
    final radius = size / 2;
    final distance = delta.distance.clamp(0.0, radius);
    final saturation = (distance / radius).clamp(0.0, 1.0);
    var hue = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    if (hue < 0) {
      hue += 360;
    }
    onChanged(hsv.withHue(hue).withSaturation(saturation));
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor hsv;

  const _ColorWheelPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final huePaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Colors.red,
          Colors.yellow,
          Colors.green,
          Colors.cyan,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, huePaint);

    final whiteFade = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, whiteFade);

    if (hsv.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value),
      );
    }

    final theta = hsv.hue * math.pi / 180.0;
    final selectorOffset =
        center +
        Offset(
          math.cos(theta) * hsv.saturation * radius,
          math.sin(theta) * hsv.saturation * radius,
        );

    canvas.drawCircle(
      selectorOffset,
      10,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(selectorOffset, 9, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      selectorOffset,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hsv != hsv;
  }
}
