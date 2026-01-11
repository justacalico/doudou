import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background(context),
      child: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                ),
                // Settings list
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                    child: Column(
                      children: [
                        // Server info section
                        _buildSection(
                          context,
                          'Server',
                          [
                            _buildSettingItem(
                              context,
                              CupertinoIcons.globe,
                              'Server',
                              'Connected',
                              onTap: () {},
                            ),
                            _buildSettingItem(
                              context,
                              CupertinoIcons.person,
                              'Account',
                              'Logged in',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        // Playback section
                        _buildSection(
                          context,
                          'Playback',
                          [
                            _buildSettingItem(
                              context,
                              CupertinoIcons.music_note,
                              'Audio Quality',
                              'Original',
                              onTap: () {},
                            ),
                            _buildSettingItem(
                              context,
                              CupertinoIcons.arrow_down_circle,
                              'Download Quality',
                              'High',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        // Account section
                        _buildSection(
                          context,
                          'Account',
                          [
                            _buildSettingItem(
                              context,
                              CupertinoIcons.square_arrow_right,
                              'Sign Out',
                              '',
                              isDestructive: true,
                              onTap: () {
                                _showSignOutDialog(context, appState);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingXXL),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingS,
            bottom: AppTheme.spacingS,
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive 
                  ? CupertinoColors.destructiveRed 
                  : AppTheme.accentPink,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive 
                      ? CupertinoColors.destructiveRed 
                      : AppTheme.textPrimary(context),
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            if (!isDestructive) ...[
              const SizedBox(width: AppTheme.spacingS),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppTheme.textSecondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AppState appState) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              appState.logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
