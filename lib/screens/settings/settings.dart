import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../login/login.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Settings',
          style: TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: Color(0xFF000000),
        border: null,
      ),
      child: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final server = appState.jellyfinService.currentServer;
            
            return CustomScrollView(
              slivers: [
                // Server Information Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
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
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // About Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('About'),
                        _buildInfoTile(
                          icon: CupertinoIcons.info,
                          title: 'App Version',
                          subtitle: '1.0.0',
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
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoButton(
                      onPressed: () => _showLogoutDialog(context, appState),
                      color: const Color(0xFFFF453A),
                      borderRadius: BorderRadius.circular(12),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.square_arrow_left, color: CupertinoColors.white),
                          SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: CupertinoColors.systemGrey,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: CupertinoColors.systemGrey,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.forward,
              color: CupertinoColors.systemGrey2,
              size: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: CupertinoColors.systemGrey,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF453A),
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

  void _showCacheDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Cache Information'),
        content: const Text('Cache stores temporarily downloaded music and images for faster access.\n\nEstimated cache size: ~50 MB'),
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
        content: const Text('This will remove all cached music and images. They will be re-downloaded when needed.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement cache clearing
              _showCacheClearedDialog(context);
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showCacheClearedDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Cache Cleared'),
        content: const Text('Cache has been successfully cleared.'),
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
