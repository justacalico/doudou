import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../l10n/app_localizations.dart';
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
                                      AppLocalizations.of(context).yourLibrary,
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppLocalizations.of(context).musicCollection,
                                      style: const TextStyle(
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
                                    AppLocalizations.of(context).albums,
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
                                    AppLocalizations.of(context).artists,
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
                                    AppLocalizations.of(context).songs,
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
                        Text(
                          AppLocalizations.of(context).quickAccess,
                          style: const TextStyle(
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
                                AppLocalizations.of(context).recentlyAdded,
                                AppLocalizations.of(context).latestAlbums,
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
                                AppLocalizations.of(context).favorites,
                                AppLocalizations.of(context).likedSongs,
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
                                AppLocalizations.of(context).topArtists,
                                AppLocalizations.of(context).mostPlayed,
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
                                AppLocalizations.of(context).playlists,
                                AppLocalizations.of(context).customMixes,
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
                        Text(
                          AppLocalizations.of(context).browse,
                          style: const TextStyle(
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
                          title: AppLocalizations.of(context).albums,
                          subtitle: AppLocalizations.of(context).albumsCount(appState.albums.length),
                          color: const Color(0xFFE91E63),
                          onTap: () => _navigateToSection(context, 'Albums'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.person_2_fill,
                          title: AppLocalizations.of(context).artists,
                          subtitle: AppLocalizations.of(context).artistsCount(appState.artists.length),
                          color: const Color(0xFF007AFF),
                          onTap: () => _navigateToSection(context, 'Artists'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.music_note,
                          title: AppLocalizations.of(context).songs,
                          subtitle: AppLocalizations.of(context).tracksCount(appState.tracks.length),
                          color: const Color(0xFF32D74B),
                          onTap: () => _navigateToSection(context, 'Songs'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.music_note_list,
                          title: AppLocalizations.of(context).playlists,
                          subtitle: AppLocalizations.of(context).playlistsCount(appState.playlists.length),
                          color: const Color(0xFFFF6B35),
                          onTap: () => _navigateToSection(context, 'Playlists'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.square_grid_2x2_fill,
                          title: AppLocalizations.of(context).collections,
                          subtitle: AppLocalizations.of(context).comingSoon,
                          color: const Color(0xFFAF52DE),
                          onTap: () => _navigateToSection(context, 'Collections'),
                        ),
                        
                        _buildEnhancedLibraryItem(
                          context,
                          appState,
                          icon: CupertinoIcons.tag_fill,
                          title: AppLocalizations.of(context).genres,
                          subtitle: AppLocalizations.of(context).comingSoon,
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
        height: 85, // Increased from 80 to 85 to prevent overflow
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
          mainAxisSize: MainAxisSize.min, // Added to prevent unnecessary expansion
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
                letterSpacing: -0.4,
                height: 1.1, // Reduced line height to save space
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
                letterSpacing: -0.4,
                height: 1.1, // Reduced line height to save space
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
    final l10n = AppLocalizations.of(context);
    Widget page;
    String title;

    switch (sectionType) {
      case 'Artists':
        page = const ArtistsTab();
        title = l10n.artists;
        break;
      case 'Albums':
        page = _buildAlbumsPage();
        title = l10n.albums;
        break;
      case 'Songs':
        page = const SongsView();
        title = l10n.songs;
        break;
      case 'Playlists':
        page = _buildPlaylistsPage();
        title = l10n.playlists;
        break;
      case 'Collections':
        page = _buildCollectionsPage();
        title = l10n.collections;
        break;
      case 'Genres':
        page = _buildGenresPage();
        title = l10n.genres;
        break;
      case 'Favorites':
        page = _buildFavoritesPage();
        title = l10n.favorites;
        break;
      default:
        page = _buildAlbumsPage();
        title = l10n.albums;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              title,
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
        final l10n = AppLocalizations.of(context);

        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.music_albums,
                  size: 64,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noAlbumsFound,
                  style: const TextStyle(
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
