import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'albums_tab.dart';
import 'artists_tab.dart';
import 'now_playing_screen.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xFF1C1C1E), // Dark background like in image
        activeColor: CupertinoColors.systemRed, // Red for active Library tab
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.music_note),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.arrow_down_circle),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: 'Search',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        Widget content;
        String title;
        
        switch (index) {
          case 0:
            content = const AlbumsTab();
            title = 'Home';
            break;
          case 1:
            content = const ArtistsTab();
            title = 'Library';
            break;
          case 2:
            content = _buildComingSoonTab('Downloads');
            title = 'Downloads';
            break;
          case 3:
            content = _buildComingSoonTab('Search');
            title = 'Search';
            break;
          default:
            content = const AlbumsTab();
            title = 'Home';
        }
        
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Dark background
          navigationBar: CupertinoNavigationBar(
            middle: Text(title, style: const TextStyle(color: CupertinoColors.white)),
            backgroundColor: const Color(0xFF1C1C1E),
            border: null,
            trailing: index <= 1 ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    context.read<AppState>().loadLibraryData();
                  },
                  child: const Icon(
                    CupertinoIcons.refresh,
                    color: CupertinoColors.white,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _showActionSheet(context);
                  },
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ) : null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(child: content),
                const MiniPlayer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComingSoonTab(String tabName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tabName == 'Downloads' ? CupertinoIcons.arrow_down_circle : CupertinoIcons.search,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          Text(
            '$tabName Coming Soon',
            style: const TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const NowPlayingScreen(),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.music_note),
                SizedBox(width: 8),
                Text('Now Playing'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppState>().logout();
            },
            isDestructiveAction: true,
            child: const Text('Logout'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
