import 'package:flutter/cupertino.dart';
import '../../home/home.dart';
import '../../libary/library.dart';
import '../../settings/settings.dart';
import '../../search/search.dart';
import '../../../widgets/mini_player.dart';

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
        backgroundColor: const Color(0xFF000000), // True black for OLED
        activeColor: CupertinoColors.systemRed, // Red for active tab
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.music_note_list),
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
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        Widget content;
        String title;
        bool showNavBar = true;
        
        switch (index) {
          case 0:
            content = const HomeContent();
            title = 'Home';
            showNavBar = false; // Home has custom header
            break;
          case 1:
            content = const LibraryContent();
            title = 'Library';
            showNavBar = false; // Library has custom header
            break;
          case 2:
            content = _buildComingSoonTab('Downloads');
            title = 'Downloads';
            break;
          case 3:
            content = const SearchScreen();
            title = 'Search';
            showNavBar = false; // Search has custom header
            break;
          case 4:
            content = const SettingsScreen();
            title = 'Settings';
            showNavBar = false; // Settings has custom header
            break;
          default:
            content = const HomeContent();
            title = 'Home';
            showNavBar = false;
        }
        
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Dark background
          navigationBar: showNavBar ? CupertinoNavigationBar(
            middle: Text(title, style: const TextStyle(color: CupertinoColors.white)),
            backgroundColor: const Color(0xFF000000), // True black for OLED
            border: null,
            trailing: null,
          ) : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: content,
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(),
              ),
            ],
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
            tabName == 'Downloads' 
                ? CupertinoIcons.arrow_down_circle 
                : CupertinoIcons.search,
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
}
