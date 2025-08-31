import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../artists/artists_tab.dart';
import '../albums/albumDetails.dart';
import '../songs/songs.dart';

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
        page = _buildAlbumsPage();
        break;
      case 'Songs':
        page = const SongsView();
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
        page = _buildAlbumsPage();
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

  Widget _buildAlbumsPage() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = appState.albums;
        
        if (albums.isEmpty) {
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
                  'No albums found',
                  style: TextStyle(
                    fontSize: 18,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await appState.loadLibraryData();
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = albums[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => AlbumDetailScreen(album: album),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFF2C2C2E),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: album.imageUrl != null
                                    ? Image.network(
                                        appState.jellyfinService.getImageUrl(
                                          album.imageUrl!,
                                          width: 300,
                                          height: 300,
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              CupertinoIcons.music_note,
                                              color: CupertinoColors.systemGrey,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Icon(
                                          CupertinoIcons.music_note,
                                          color: CupertinoColors.systemGrey,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            album.name,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (album.artistName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              album.artistName!,
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (album.year != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              album.year.toString(),
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  childCount: albums.length,
                ),
              ),
            ),
            // Add a bit of bottom padding for scrolling
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
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
