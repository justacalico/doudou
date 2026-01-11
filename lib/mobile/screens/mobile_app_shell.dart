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

/// Main mobile app shell with Apple Music-style tab bar
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
    SearchScreen(),
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
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.separator(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTabItem(
                              context,
                              0,
                              CupertinoIcons.play_circle,
                              CupertinoIcons.play_circle_fill,
                              'Listen Now',
                            ),
                            _buildTabItem(
                              context,
                              1,
                              CupertinoIcons.music_albums,
                              CupertinoIcons.music_albums_fill,
                              'Library',
                            ),
                            _buildTabItem(
                              context,
                              2,
                              CupertinoIcons.search,
                              CupertinoIcons.search,
                              'Search',
                            ),
                          ],
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
    final color = isSelected ? AppTheme.accentPink : AppTheme.textSecondary(context);

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
