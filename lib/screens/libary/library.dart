import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../artists/artists.dart';
import '../shared/detail_track_view.dart';
import '../songs/songs.dart';
import '../playlists/playlists.dart';
import '../favorites/favorites.dart';

class LibraryContent extends StatelessWidget {
  const LibraryContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Enhanced header with gradient background
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1C1C1E).withOpacity(0.8),
                          const Color(0xFF000000).withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with profile icon
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE91E63).withOpacity(0.3),
                                      offset: const Offset(0, 4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.person,
                                  color: CupertinoColors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Library',
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Music Collection',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Library stats card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2C2C2E).withOpacity(0.8),
                                  const Color(0xFF1C1C1E).withOpacity(0.6),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFE91E63).withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    '${appState.albums.length}',
                                    'Albums',
                                    CupertinoIcons.music_albums,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: const Color(0xFF3C3C3E),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    '${appState.artists.length}',
                                    'Artists',
                                    CupertinoIcons.music_mic,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: const Color(0xFF3C3C3E),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    '${appState.tracks.length}',
                                    'Songs',
                                    CupertinoIcons.music_note,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                // Quick access section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Access',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Grid of quick access items
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickAccessCard(
                                context,
                                appState,
                                'Recently Added',
                                'Latest albums',
                                CupertinoIcons.clock,
                                const Color(0xFFE91E63),
                                () => _navigateToSection(context, 'Albums'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickAccessCard(
                                context,
                                appState,
                                'Favorites',
                                'Liked songs',
                                CupertinoIcons.heart_fill,
                                const Color(0xFFFF6B35),
                                () => _navigateToSection(context, 'Favorites'),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickAccessCard(
                                context,
                                appState,
                                'Top Artists',
                                'Most played',
                                CupertinoIcons.music_mic,
                                const Color(0xFF007AFF),
                                () => _navigateToSection(context, 'Artists'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickAccessCard(
                                context,
                                appState,
                                'Playlists',
                                'Custom mixes',
                                CupertinoIcons.music_note_list,
                                const Color(0xFF32D74B),
                                () => _navigateToSection(context, 'Playlists'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                
                // Browse categories section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Browse',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Enhanced library navigation items
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.music_albums_fill,
                          title: 'Albums',
                          subtitle: '${appState.albums.length} albums',
                          color: const Color(0xFFE91E63),
                          onTap: () => _navigateToSection(context, 'Albums'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.person_2_fill,
                          title: 'Artists',
                          subtitle: '${appState.artists.length} artists',
                          color: const Color(0xFF007AFF),
                          onTap: () => _navigateToSection(context, 'Artists'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.music_note,
                          title: 'Songs',
                          subtitle: '${appState.tracks.length} tracks',
                          color: const Color(0xFF32D74B),
                          onTap: () => _navigateToSection(context, 'Songs'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.music_note_list,
                          title: 'Playlists',
                          subtitle: '${appState.playlists.length} playlists',
                          color: const Color(0xFFFF6B35),
                          onTap: () => _navigateToSection(context, 'Playlists'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.square_grid_2x2_fill,
                          title: 'Collections',
                          subtitle: 'Coming soon',
                          color: const Color(0xFFAF52DE),
                          onTap: () => _navigateToSection(context, 'Collections'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.tag_fill,
                          title: 'Genres',
                          subtitle: 'Coming soon',
                          color: const Color(0xFFFF9F0A),
                          onTap: () => _navigateToSection(context, 'Genres'),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom padding for mini player
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFE91E63),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.systemGrey.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildQuickAccessCard(
    BuildContext context,
    AppState appState,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: CupertinoColors.systemGrey.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnhancedLibraryItem(
    BuildContext context,
    AppState appState, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1C1C1E).withOpacity(0.6),
            border: Border.all(
              color: const Color(0xFF3C3C3E).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: CupertinoColors.systemGrey.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }  void _navigateToSection(BuildContext context, String sectionType) {
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  final album = albums[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => DetailTrackView.album(album),
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
                                      appState.getImageUrl(
                                        album.imageUrl!,
                                        width: 300,
                                        height: 300,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                CupertinoIcons.music_note,
                                                color:
                                                    CupertinoColors.systemGrey,
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
                }, childCount: albums.length),
              ),
            ),
            // Add bottom padding for mini player + nav bar
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
              ), // Space for mini player (70px) + nav bar (65px) + extra padding
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsPage() {
    return const PlaylistsView();
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
            style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
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
            style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesPage() {
    return const FavoritesView();
  }
}
