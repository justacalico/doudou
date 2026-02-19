import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../services/base_service.dart';
import '../../services/update_service.dart';
import '../theme.dart';
import '../widgets/page_template.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _notificationMessage;
  Color? _notificationColor;

  void _showNotification(String message, {Color? color}) {
    setState(() {
      _notificationMessage = message;
      _notificationColor = color;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() {
        _notificationMessage = null;
        _notificationColor = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          PageTemplate(
            title: l10n.settings,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AudioSection(onNotification: _showNotification),
                  _AppearanceSection(onNotification: _showNotification),
                  _ServerSection(onNotification: _showNotification),
                  _AboutSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_notificationMessage != null) _buildNotificationBanner(),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Material(
            color: _notificationColor ?? Colors.green,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
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
                    onPressed: () => setState(() {
                      _notificationMessage = null;
                      _notificationColor = null;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioSection extends StatelessWidget {
  final void Function(String message, {Color? color}) onNotification;

  const _AudioSection({required this.onNotification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _Section(
          title: 'Audio',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Smart back button'),
                subtitle: const Text(
                  'If past 20%: first back restarts, second back goes to previous track',
                ),
                value: appState.smartBackToStartEnabled,
                onChanged: (v) => appState.toggleSmartBackToStart(v),
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  final void Function(String message, {Color? color}) onNotification;

  const _AppearanceSection({required this.onNotification});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _Section(
          title: l10n.appearanceSettings,
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.appTheme),
                subtitle: Text(_themeName(appState.themeMode)),
                onTap: () => _showThemeDialog(context, appState),
              ),
              ListTile(
                title: Text(l10n.accentColor),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: appState.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => _showColorDialog(context, appState),
              ),
              ListTile(
                title: Text(l10n.selectLanguage),
                subtitle: Text(appState.locale?.languageCode ?? 'System'),
                onTap: () => _showLanguageDialog(context, appState),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('OLED dark mode'),
                subtitle: const Text('Pure black backgrounds'),
                value: appState.oledDarkModeEnabled,
                onChanged: appState.toggleOledDarkMode,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  String _themeName(dynamic mode) {
    if (mode == ThemeMode.light) return 'Light';
    if (mode == ThemeMode.dark) return 'Dark';
    return 'System';
  }

  void _showThemeDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System'),
              onTap: () {
                Navigator.pop(ctx);
                appState.setThemeMode(ThemeMode.system);
              },
            ),
            ListTile(
              title: const Text('Light'),
              onTap: () {
                Navigator.pop(ctx);
                appState.setThemeMode(ThemeMode.light);
              },
            ),
            ListTile(
              title: const Text('Dark'),
              onTap: () {
                Navigator.pop(ctx);
                appState.setThemeMode(ThemeMode.dark);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorDialog(BuildContext context, AppState appState) {
    final colors = <String, Color>{
      'Purple': Colors.purple,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Orange': Colors.orange,
      'Red': Colors.red,
      'Teal': Colors.teal,
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Accent color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in colors.entries)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  appState.setAccentColor(entry.value);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Language'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('System default'),
                onTap: () {
                  Navigator.pop(ctx);
                  appState.setLocale(null);
                },
              ),
              ...AppLocalizations.supportedLocales.map((locale) => ListTile(
                    title: Text(locale.languageCode),
                    onTap: () {
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
}

class _ServerSection extends StatelessWidget {
  final void Function(String message, {Color? color}) onNotification;

  const _ServerSection({required this.onNotification});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final isLocal = appState.mediaServiceManager.currentServerType == ServerType.local;
        final servers = appState.configuredServers;

        return _Section(
          title: isLocal ? 'Local Music' : l10n.serverSettings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: () => _showAddServerDialog(context, appState),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Server'),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              if (servers.isNotEmpty) ...[
                Text(
                  'Configured servers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ...servers.map((server) {
                  final id = server['id'] ?? '';
                  final type = server['type'] ?? 'unknown';
                  final url = server['url'] ?? '';
                  final displayName = server['displayName']?.trim();
                  final label = displayName?.isNotEmpty == true
                      ? displayName!
                      : (url == 'local' ? 'Local Music' : (url.length > 40 ? '${url.substring(0, 37)}...' : url));
                  final isActive = id == appState.activeServerId;
                  return ListTile(
                    leading: Icon(
                      type == 'local' ? Icons.folder_rounded : Icons.dns_rounded,
                      color: isActive ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$type${isActive ? ' (Active)' : ''}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          TextButton(
                            onPressed: () async {
                              final ok = await appState.switchToServer(id);
                              if (context.mounted) {
                                onNotification(ok ? 'Switched' : 'Failed', color: ok ? null : Colors.red);
                              }
                            },
                            child: const Text('Switch'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppTheme.surface,
                                title: const Text('Remove server'),
                                content: Text('Remove "$label"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await appState.removeServer(id);
                              if (context.mounted) onNotification('Removed');
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppTheme.spacingMd),
              ListTile(
                title: Text(isLocal ? 'Music source' : l10n.connection),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appState.isLoggedIn ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    appState.isLoggedIn ? (isLocal ? 'Active' : l10n.authenticated) : 'Disconnected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Refresh library'),
                leading: const Icon(Icons.refresh_rounded),
                onTap: () async {
                  await appState.loadLibraryData();
                  if (context.mounted) onNotification('Library refreshed');
                },
              ),
              if (isLocal && appState.mediaServiceManager.localMusicService != null) ...[
                const Divider(),
                ListTile(
                  title: const Text('Add directory'),
                  leading: const Icon(Icons.folder_rounded),
                  onTap: () async {
                    final result = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'Select music folder',
                    );
                    if (result != null) {
                      await appState.mediaServiceManager.addLocalMusicDirectory(result);
                      if (context.mounted) onNotification('Added ${result.split('/').last}');
                    }
                  },
                ),
                ListTile(
                  title: const Text('Rescan library'),
                  leading: const Icon(Icons.refresh_rounded),
                  onTap: () async {
                    final local = appState.mediaServiceManager.localMusicService!;
                    await local.scanDirectories();
                    if (context.mounted) {
                      onNotification('Scan complete');
                      await appState.loadLibraryData();
                    }
                  },
                ),
              ],
              const Divider(),
              ListTile(
                title: const Text('Sign out'),
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                textColor: Colors.red,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Sign out'),
                      content: const Text(
                        'Are you sure? You will need to log in again to access your music.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign out', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    appState.logout();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Clear image cache'),
                leading: const Icon(Icons.delete_outline_rounded),
                onTap: () async {
                  await appState.clearImageCache();
                  if (context.mounted) onNotification('Cache cleared');
                },
              ),
              ListTile(
                title: const Text('Clear all cache'),
                leading: const Icon(Icons.delete_sweep_rounded),
                onTap: () async {
                  await appState.clearAllCache();
                  if (context.mounted) onNotification('All cache cleared');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddServerDialog(BuildContext context, AppState appState) async {
    final urlController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Server'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Server type: Jellyfin (URL + username + password)'),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://jellyfin.example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              final user = userController.text.trim();
              final pass = passController.text;
              if (url.isEmpty || user.isEmpty) return;
              Navigator.pop(ctx);
              final success = await appState.loginWithServerType(
                'jellyfin',
                url,
                user,
                pass,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Connected' : 'Failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: 'About Doudou',
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              final v = snap.data?.version ?? '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Version $v',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const Text(
            'A beautiful music player for anyone anywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final info = await UpdateService.checkForUpdate();
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: Text(info.updateAvailable ? 'Update available' : 'Up to date'),
                  content: Text(
                    info.updateAvailable
                        ? 'Current: ${info.currentVersion}\nLatest: ${info.latestVersion}'
                        : 'You have the latest version.',
                  ),
                  actions: [
                    if (info.updateAvailable)
                      TextButton(
                        onPressed: () {
                          launchUrl(Uri.parse('https://openlyst.ink/apps/doudou'));
                          Navigator.pop(ctx);
                        },
                        child: const Text('View update'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check for updates'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
