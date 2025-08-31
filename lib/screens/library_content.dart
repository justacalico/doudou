import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'albums_tab.dart';
import 'artists_tab.dart';

class LibraryContent extends StatelessWidget {
  const LibraryContent({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Library', style: TextStyle(color: CupertinoColors.white, fontSize: 34, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000000),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // Cast/airplay functionality
              },
              child: const Icon(
                CupertinoIcons.antenna_radiowaves_left_right,
                color: CupertinoColors.systemRed,
                size: 24,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // Profile functionality
              },
              child: const Icon(
                CupertinoIcons.person_circle,
                color: CupertinoColors.systemRed,
                size: 24,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.music_mic,
                      title: 'Artists',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Artists'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.rectangle_stack,
                      title: 'Albums',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Albums'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.music_note,
                      title: 'Songs',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Songs'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.music_note_list,
                      title: 'Playlists',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Playlists'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.square_grid_2x2,
                      title: 'Collections',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Collections'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.music_albums,
                      title: 'Genres',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Genres'),
                    ),
                    _buildLibraryItem(
                      context,
                      icon: CupertinoIcons.heart,
                      title: 'Favorites',
                      color: const Color(0xFFFF453A),
                      onTap: () => _navigateToSection(context, 'Favorites'),
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

  Widget _buildLibraryItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: CupertinoColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSection(BuildContext context, String sectionType) {
    Widget page;
    
    switch (sectionType) {
      case 'Artists':
        page = const ArtistsTab();
        break;
      case 'Albums':
        page = const AlbumsTab();
        break;
      case 'Songs':
        page = _buildSongsPage();
        break;
      case 'Playlists':
        page = _buildPlaylistsPage();
        break;
      case 'Collections':
        page = _buildCollectionsPage();
        break;
      case 'Genres':
        page = _buildGenresPage();
        break;
      case 'Favorites':
        page = _buildFavoritesPage();
        break;
      default:
        page = const AlbumsTab();
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              sectionType,
              style: const TextStyle(color: CupertinoColors.white),
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            border: null,
          ),
          child: page,
        ),
      ),
    );
  }

  Widget _buildSongsPage() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Songs will be loaded from your albums',
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to Albums to see songs
                        _navigateToSection(context, 'Albums');
                      },
                      child: const Text('Browse Albums'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.music_note_list,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            'Playlists Coming Soon',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.square_grid_2x2,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            'Collections Coming Soon',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.music_albums,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            'Genres Coming Soon',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.heart,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            'Favorites Coming Soon',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
