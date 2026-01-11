import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/apple_design/liquid_glass.dart';
import '../../../services/base_service.dart';
import '../login/login.dart';
import 'partials/account_information.dart';
import 'partials/audio_settings.dart';
import 'partials/language_settings.dart';
import 'logs_viewer.dart';
import 'local_music_settings.dart';
import 'components.dart';

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
    return LiquidGradientBackground(
      child: CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              return CustomScrollView(
                slivers: [
                  // Custom header for iOS-style left-aligned title with glass effect
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        20.0,
                      ),
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
                  const SliverToBoxAdapter(child: AccountInformationSection()),

                  // Audio Settings Section
                  const SliverToBoxAdapter(child: AudioSettingsSection()),

                  // Language Settings Section
                  const SliverToBoxAdapter(child: LanguageSettingsSection()),

                  // Player Interface Section
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      title: AppLocalizations.of(context).playerInterface,
                      children: [
                        SettingsSwitchTile(
                          icon: CupertinoIcons.rectangle_3_offgrid,
                          title: AppLocalizations.of(context).dynamicIslePlayer,
                          subtitle: AppLocalizations.of(
                            context,
                          ).useModernFloatingPlayer,
                          value: appState.useDynamicIsle,
                          onChanged: (value) =>
                              appState.toggleDynamicIsle(value),
                        ),
                      ],
                    ),
                  ),

                  // Storage & Cache Section
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      title: AppLocalizations.of(context).storageAndCache,
                      children: [
                        SettingsTile(
                          icon: CupertinoIcons.folder,
                          title: AppLocalizations.of(context).cacheSize,
                          subtitle: _cacheSize,
                          onTap: () => _showCacheDialog(context),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.trash,
                          title: AppLocalizations.of(context).clearCacheOptions,
                          subtitle: AppLocalizations.of(context).freeUpStorage,
                          onTap: () => _showClearCacheDialog(context),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.refresh,
                          title: AppLocalizations.of(context).cleanExpiredCache,
                          subtitle: AppLocalizations.of(
                            context,
                          ).removeOldCachedData,
                          onTap: () => _cleanExpiredCache(context),
                        ),
                      ],
                    ),
                  ),

                  // Local Music Section (only show when using local music)
                  if (appState.mediaServiceManager.currentServerType ==
                      ServerType.local)
                    SliverToBoxAdapter(
                      child: SettingsSection(
                        title: 'Local Music',
                        children: [
                          SettingsTile(
                            icon: CupertinoIcons.folder_badge_plus,
                            title: 'Manage Directories',
                            subtitle: 'Add or remove music folders',
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) =>
                                    const LocalMusicSettingsScreen(),
                              ),
                            ),
                          ),
                          SettingsTile(
                            icon: CupertinoIcons.arrow_2_circlepath,
                            title: 'Rescan Library',
                            subtitle: 'Scan directories for new music',
                            onTap: () => _rescanLocalMusic(context, appState),
                          ),
                        ],
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Logs & Diagnostics Section
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      title: AppLocalizations.of(context).logsAndDiagnostics,
                      children: [
                        SettingsSwitchTile(
                          icon: CupertinoIcons.doc_text,
                          title: AppLocalizations.of(context).enableLogging,
                          subtitle: AppLocalizations.of(
                            context,
                          ).recordAppActivity,
                          value: appState.loggingEnabled,
                          onChanged: (value) => appState.toggleLogging(value),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.doc_text_viewfinder,
                          title: AppLocalizations.of(
                            context,
                          ).viewApplicationLogs,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // About Section
                  SliverToBoxAdapter(
                    child: SettingsSection(
                      title: AppLocalizations.of(context).about,
                      children: [
                        SettingsInfoTile(
                          icon: CupertinoIcons.info,
                          title: AppLocalizations.of(context).appVersion,
                          subtitle: _appVersion,
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.doc_text,
                          title: AppLocalizations.of(context).licenses,
                          subtitle: AppLocalizations.of(
                            context,
                          ).viewOpenSourceLicenses,
                          onTap: () => _showLicensesDialog(context),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.link,
                          title: AppLocalizations.of(context).gitLabRepository,
                          subtitle: AppLocalizations.of(
                            context,
                          ).viewSourceAndContribute,
                          onTap: () => _openGitLabPage(context),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.heart,
                          title: AppLocalizations.of(
                            context,
                          ).supportDevelopment,
                          subtitle: AppLocalizations.of(
                            context,
                          ).helpSupportProject,
                          onTap: () => _showSupportDialog(context),
                        ),
                        SettingsTile(
                          icon: CupertinoIcons.globe,
                          title: AppLocalizations.of(context).developerWebsite,
                          subtitle: AppLocalizations.of(
                            context,
                          ).visitOurWebsite,
                          onTap: () => _openDeveloperWebsite(context),
                        ),
                      ],
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Refresh Data Section
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CupertinoButton(
                        onPressed: appState.isLoading
                            ? null
                            : () => _refreshLibraryData(context, appState),
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
                              appState.isLoading
                                  ? AppLocalizations.of(context).refreshing
                                  : AppLocalizations.of(context).refreshLibrary,
                              style: TextStyle(
                                color: appState.isLoading
                                    ? const Color(0xFFFFFFFF).withOpacity(0.6)
                                    : const Color(0xFFFFFFFF),
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
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withOpacity(0.3),
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

                  // Bottom padding to clear mini player and navbar
                  const SliverToBoxAdapter(child: SizedBox(height: 180)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper widget builders have been refactored into reusable components
  // in `components.dart`.

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
        imageSizeText =
            '${(imageCacheSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else if (imageCacheSize > 1024) {
        imageSizeText = '${(imageCacheSize / 1024).toStringAsFixed(1)} KB';
      } else {
        imageSizeText = '$imageCacheSize bytes';
      }
    } else {
      imageSizeText = '0 MB';
    }

    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.cacheInfo),
        content: Text(
          '${l10n.cacheDescription}\n\n'
          '${l10n.dataCache}: $totalDataEntries entries\n'
          '${l10n.imageCache}: $imageSizeText',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.clearCacheOptions),
        content: Text(l10n.selectClearOption),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _clearDataCache(context);
            },
            child: Text(l10n.dataCache),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _clearImageCache(context);
            },
            child: Text(l10n.imageCache),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllCache(context);
            },
            child: Text(l10n.clearAllCache),
          ),
        ],
      ),
    );
  }

  void _showCacheClearedDialog(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.cacheClearedTitle(type)),
        content: Text(l10n.cacheClearedMessage(type)),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
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
      _showCacheClearedDialog(context, AppLocalizations.of(context).data);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        '${AppLocalizations.of(context).failedToClearCache(AppLocalizations.of(context).data)}: $e',
      );
    }
  }

  void _clearImageCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearImageCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      _showCacheClearedDialog(context, AppLocalizations.of(context).image);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        '${AppLocalizations.of(context).failedToClearCache(AppLocalizations.of(context).image)}: $e',
      );
    }
  }

  void _clearAllCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.clearAllCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      _showCacheClearedDialog(context, AppLocalizations.of(context).all);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        '${AppLocalizations.of(context).failedToClearCache(AppLocalizations.of(context).all)}: $e',
      );
    }
  }

  void _cleanExpiredCache(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.cleanupExpiredCache();
      await _loadCacheSize(); // Refresh cache size display
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(l10n.cacheCleanedTitle),
          content: Text(l10n.expiredCacheRemoved),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: Text(l10n.ok),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(
        context,
        AppLocalizations.of(context).failedToCleanExpiredCache,
      );
    }
  }

  void _rescanLocalMusic(BuildContext context, AppState appState) async {
    final localService = appState.mediaServiceManager.localMusicService;
    if (localService == null) return;

    // Show progress dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CupertinoAlertDialog(
        title: Text('Scanning...'),
        content: Padding(
          padding: EdgeInsets.all(16),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      await appState.mediaServiceManager.scanLocalMusicDirectories();

      // Reload library data
      await appState.loadLibraryData();

      if (!context.mounted) return;
      Navigator.pop(context); // Close progress dialog

      final trackCount = (await localService.getTracks()).length;

      if (!context.mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Scan Complete'),
          content: Text('Found $trackCount tracks'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close progress dialog
      _showErrorDialog(context, 'Scan failed: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.error),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.openSourceLicenses),
        content: Text(l10n.licensesDescription),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
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
      final l10n = AppLocalizations.of(context);
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.gitLabRepository),
          content: Text(
            '${l10n.gitlabUrlCopied}\n\nhttps://gitlab.com/Openlyst/doudou\n\n${l10n.gitlabUrlDescription}',
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(l10n.ok),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.error),
          content: Text('${l10n.failedToCopyUrl} $url'),
          actions: [
            CupertinoDialogAction(
              child: Text(l10n.ok),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  void _showSupportDialog(BuildContext context) async {
    final url = Uri.parse('https://communistparty.ie/en/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // URL launch failed
    }
  }

  void _openDeveloperWebsite(BuildContext context) async {
    final url = Uri.parse('https://openlyst.ink/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // URL launch failed
    }
  }

  Future<void> _refreshLibraryData(
    BuildContext context,
    AppState appState,
  ) async {
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
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.libraryRefreshed),
        content: Text(l10n.libraryRefreshedSuccess),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showRefreshErrorDialog(BuildContext context, String error) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.refreshFailed),
        content: Text(
          '${l10n.failedToRefreshLibrary}\n\n${l10n.error}: $error',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
