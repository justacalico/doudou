import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/apple_design/liquid_glass.dart';
import '../artists/artists.dart';
import '../shared/detail_track_view.dart';
import '../songs/songs.dart';
import '../playlists/playlists.dart';
import '../favorites/favorites.dart';

// Cached blur filter to avoid recreation on each build
final _libraryBlur10 = ImageFilter.blur(sigmaX: 10, sigmaY: 10);

class LibraryContent extends StatelessWidget {
  const LibraryContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<
      AppState,
      ({int albums, int artists, int tracks, int playlists, int favorites})
    >(
      selector: (_, state) => (
        albums: state.albums.length,
        artists: state.artists.length,
        tracks: state.tracks.length,
        playlists: state.playlists.length,
        favorites: state.favoriteTracks.length,
      ),
      builder: (context, counts, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          child: Stack(
            children: [
              // Animated gradient background
              LiquidGradientBackground(
                colors: const [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A0A1A),
                  Color(0xFF0A1A1A),
                ],
                child: SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      // Enhanced header with liquid glass
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with profile icon
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFFEC4899),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF8B5CF6,
                                          ).withOpacity(0.4),
                                          offset: const Offset(0, 4),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.person,
                                      color: CupertinoColors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).yourLibrary,
                                          style: TextStyle(
                                            color: CupertinoColors.white
                                                .withOpacity(0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).musicCollection,
                                          style: const TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 26,
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

                              // Library stats card with liquid glass
                              LiquidGlassMaterial(
                                borderRadius: 20,
                                padding: const EdgeInsets.all(20),
                                tintColor: const Color(0xFF8B5CF6),
                                tintOpacity: 0.1,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatItem(
                                        '${counts.albums}',
                                        AppLocalizations.of(context).albums,
                                        CupertinoIcons.music_albums,
                                        const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: CupertinoColors.white.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatItem(
                                        '${counts.artists}',
                                        AppLocalizations.of(context).artists,
                                        CupertinoIcons.music_mic,
                                        const Color(0xFFEC4899),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: CupertinoColors.white.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatItem(
                                        '${counts.tracks}',
                                        AppLocalizations.of(context).songs,
                                        CupertinoIcons.music_note,
                                        const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Grid of quick access items
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickAccessCard(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      ).recentlyAdded,
                                      AppLocalizations.of(context).latestAlbums,
                                      CupertinoIcons.clock,
                                      const Color(0xFF8B5CF6),
                                      () =>
                                          _navigateToSection(context, 'Albums'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildQuickAccessCard(
                                      context,
                                      AppLocalizations.of(context).favorites,
                                      AppLocalizations.of(context).likedSongs,
                                      CupertinoIcons.heart_fill,
                                      const Color(0xFFEC4899),
                                      () => _navigateToSection(
                                        context,
                                        'Favorites',
                                      ),
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
                                      AppLocalizations.of(context).topArtists,
                                      AppLocalizations.of(context).mostPlayed,
                                      CupertinoIcons.music_mic,
                                      const Color(0xFF3B82F6),
                                      () => _navigateToSection(
                                        context,
                                        'Artists',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildQuickAccessCard(
                                      context,
                                      AppLocalizations.of(context).playlists,
                                      AppLocalizations.of(context).customMixes,
                                      CupertinoIcons.music_note_list,
                                      const Color(0xFF10B981),
                                      () => _navigateToSection(
                                        context,
                                        'Playlists',
                                      ),
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.music_albums_fill,
                                title: AppLocalizations.of(context).albums,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).albumsCount(counts.albums),
                                color: const Color(0xFF8B5CF6),
                                onTap: () =>
                                    _navigateToSection(context, 'Albums'),
                              ),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.person_2_fill,
                                title: AppLocalizations.of(context).artists,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).artistsCount(counts.artists),
                                color: const Color(0xFFEC4899),
                                onTap: () =>
                                    _navigateToSection(context, 'Artists'),
                              ),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.music_note,
                                title: AppLocalizations.of(context).songs,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).tracksCount(counts.tracks),
                                color: const Color(0xFF10B981),
                                onTap: () =>
                                    _navigateToSection(context, 'Songs'),
                              ),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.music_note_list,
                                title: AppLocalizations.of(context).playlists,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).playlistsCount(counts.playlists),
                                color: const Color(0xFF3B82F6),
                                onTap: () =>
                                    _navigateToSection(context, 'Playlists'),
                              ),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.square_grid_2x2_fill,
                                title: AppLocalizations.of(context).collections,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).comingSoon,
                                color: const Color(0xFFF59E0B),
                                onTap: () =>
                                    _navigateToSection(context, 'Collections'),
                              ),

                              _buildEnhancedLibraryItem(
                                context,
                                icon: CupertinoIcons.tag_fill,
                                title: AppLocalizations.of(context).genres,
                                subtitle: AppLocalizations.of(
                                  context,
                                ).comingSoon,
                                color: const Color(0xFFEF4444),
                                onTap: () =>
                                    _navigateToSection(context, 'Genres'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: _libraryBlur10,
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.3), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: CupertinoColors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedLibraryItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: _libraryBlur10,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: CupertinoColors.white.withOpacity(0.08),
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.3),
                            color.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 24),
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
                              color: CupertinoColors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: CupertinoColors.white.withOpacity(0.4),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSection(BuildContext context, String sectionType) {
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
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.square_grid_2x2,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.collectionsComingSoon,
                style: const TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenresPage() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
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
                l10n.genresComingSoon,
                style: const TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesPage() {
    return const FavoritesView();
  }
}
