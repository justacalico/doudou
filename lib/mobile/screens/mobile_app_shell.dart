import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'now_playing_screen.dart';
import 'settings_screen.dart';

/// Main mobile app shell with modern tab bar
class MobileAppShell extends StatefulWidget {
  const MobileAppShell({super.key});

  @override
  State<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends State<MobileAppShell> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    DownloadsScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, snapshot) {
            final hasCurrentTrack = snapshot.data != null || 
                appState.audioHandler?.currentTrack != null;

            return CupertinoPageScaffold(
              backgroundColor: AppTheme.background(context),
              child: Column(
                children: [
                  // Main content area
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                  // Mini player (shows above tab bar when playing)
                  if (hasCurrentTrack)
                    MiniPlayer(
                      onTap: () => _openNowPlaying(context),
                    ),
                  // Tab bar with frosted glass
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.transparent,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: CupertinoColors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildTabItem(
                                    context,
                                    0,
                                    CupertinoIcons.house,
                                    CupertinoIcons.house_fill,
                                    'Home',
                                  ),
                                  _buildTabItem(
                                    context,
                                    1,
                                    CupertinoIcons.music_note_list,
                                    CupertinoIcons.music_note_list,
                                    'Library',
                                  ),
                                  _buildTabItem(
                                    context,
                                    2,
                                    CupertinoIcons.arrow_down_circle,
                                    CupertinoIcons.arrow_down_circle_fill,
                                    'Downloads',
                                  ),
                                  _buildTabItem(
                                    context,
                                    3,
                                    CupertinoIcons.search,
                                    CupertinoIcons.search,
                                    'Search',
                                  ),
                                  _buildTabItem(
                                    context,
                                    4,
                                    CupertinoIcons.gear,
                                    CupertinoIcons.gear_solid,
                                    'Settings',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.accentPink.withOpacity(0.2)
                      : CupertinoColors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected 
                      ? AppTheme.accentPink 
                      : CupertinoColors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected 
                      ? AppTheme.accentPink 
                      : CupertinoColors.white.withOpacity(0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
