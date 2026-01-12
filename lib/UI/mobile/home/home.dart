import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../widgets/apple_design/liquid_glass.dart';
import '../shared/detail_track_view.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Album>? _shuffledAlbums;
  List<Album>? _continueListeningAlbums;
  List<Album>? _madeForYouAlbums;
  List<Album>? _recommendedAlbums;
  List<Album>? _similarToFavoritesAlbums;
  DateTime? _lastShuffleAllTap;
  DateTime? _lastShuffleFavoritesTap;

  void _initializeAlbumLists(
    List<Album> allAlbums,
    List<Track> favoriteTracks,
  ) {
    if (_shuffledAlbums == null || _shuffledAlbums!.isEmpty) {
      _shuffledAlbums = List<Album>.from(allAlbums)..shuffle();

      // Get personalized recommendations based on favorites
      _recommendedAlbums = _getRecommendedAlbums(allAlbums, favoriteTracks);
      _continueListeningAlbums = _getContinueListeningAlbums(
        allAlbums,
        favoriteTracks,
      );
      _madeForYouAlbums = _getMadeForYouAlbums(allAlbums, favoriteTracks);
      _similarToFavoritesAlbums = _getSimilarToFavoritesAlbums(
        allAlbums,
        favoriteTracks,
      );
    }
  }

  List<Album> _getRecommendedAlbums(
    List<Album> allAlbums,
    List<Track> favoriteTracks,
  ) {
    // Sort albums by date added (most recent first)
    final sortedAlbums = List<Album>.from(allAlbums);
    sortedAlbums.sort((a, b) {
      // If both albums have dateCreated, compare them
      if (a.dateCreated != null && b.dateCreated != null) {
        return b.dateCreated!.compareTo(a.dateCreated!);
      }
      // If only one has dateCreated, prioritize it
      if (a.dateCreated != null) return -1;
      if (b.dateCreated != null) return 1;
      // If neither has dateCreated, maintain original order
      return 0;
    });

    return sortedAlbums.take(6).toList();
  }

  List<Album> _getContinueListeningAlbums(
    List<Album> allAlbums,
    List<Track> favoriteTracks,
  ) {
    if (favoriteTracks.isEmpty) {
      return allAlbums.take(4).toList();
    }

    // Get albums that contain favorite tracks
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final continueListeningAlbums = allAlbums
        .where((album) => favoriteAlbumIds.contains(album.id))
        .toList();

    return continueListeningAlbums.take(4).toList();
  }

  List<Album> _getMadeForYouAlbums(
    List<Album> allAlbums,
    List<Track> favoriteTracks,
  ) {
    if (favoriteTracks.isEmpty) {
      return allAlbums.take(4).toList();
    }

    // Get albums from the same artists as favorite tracks
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    final albumsByFavoriteArtists = allAlbums
        .where(
          (album) =>
              album.artistName != null &&
              favoriteArtistNames.contains(album.artistName!),
        )
        .toList();

    // Remove albums that contain favorite tracks (to avoid duplicates with continue listening)
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final madeForYou =
        albumsByFavoriteArtists
            .where((album) => !favoriteAlbumIds.contains(album.id))
            .toList()
          ..shuffle();

    if (madeForYou.length >= 4) {
      return madeForYou.take(4).toList();
    }

    // Fill with other albums if needed
    final otherAlbums =
        allAlbums
            .where(
              (album) =>
                  (album.artistName == null ||
                      !favoriteArtistNames.contains(album.artistName!)) &&
                  !favoriteAlbumIds.contains(album.id),
            )
            .toList()
          ..shuffle();

    madeForYou.addAll(otherAlbums.take(4 - madeForYou.length));
    return madeForYou;
  }

  List<Album> _getSimilarToFavoritesAlbums(
    List<Album> allAlbums,
    List<Track> favoriteTracks,
  ) {
    if (favoriteTracks.isEmpty) {
      return [];
    }

    // Get albums from the same artists as favorite tracks
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    // Get albums that user hasn't favorited tracks from yet
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final similarAlbums =
        allAlbums
            .where(
              (album) =>
                  album.artistName != null &&
                  favoriteArtistNames.contains(album.artistName!) &&
                  !favoriteAlbumIds.contains(album.id),
            )
            .toList()
          ..shuffle();

    return similarAlbums.take(6).toList();
  }

  void _showNoFavoritesDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(l10n.noFavorites),
        content: Text(l10n.noFavoritesYet),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Selector<
      AppState,
      ({List<Album> albums, List<Track> favorites, bool isLoading})
    >(
      selector: (_, state) => (
        albums: state.albums,
        favorites: state.favoriteTracks,
        isLoading: state.isLoading,
      ),
      shouldRebuild: (prev, next) =>
          prev.albums.length != next.albums.length ||
          prev.favorites.length != next.favorites.length ||
          prev.isLoading != next.isLoading,
      builder: (context, data, child) {
        final allAlbums = data.albums;
        final favoriteTracks = data.favorites;
        _initializeAlbumLists(allAlbums, favoriteTracks);

        final recentAlbums = _recommendedAlbums ?? allAlbums.take(6).toList();
        final continueListeningAlbums =
            _continueListeningAlbums ?? allAlbums.take(4).toList();
        final madeForYouAlbums =
            _madeForYouAlbums ?? allAlbums.take(4).toList();
        final similarToFavoritesAlbums = _similarToFavoritesAlbums ?? [];

        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          child: LiquidGradientBackground(
            colors: const [
              Color(0xFF0D0D0D),
              Color(0xFF1A0A1A),
              Color(0xFF0A1A1A),
            ],
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top padding for safe area
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.top + 16,
                  ),
                ),

                // Liquid glass shuffle buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLiquidGlassShuffleButton(
                            icon: CupertinoIcons.shuffle,
                            label: l10n.shuffleAll,
                            onPressed: () async {
                              final now = DateTime.now();
                              if (_lastShuffleAllTap != null &&
                                  now.difference(_lastShuffleAllTap!) <
                                      const Duration(milliseconds: 1000)) {
                                return;
                              }
                              _lastShuffleAllTap = now;
                              await context.read<AppState>().shuffleAllTracks();
                            },
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLiquidGlassShuffleButton(
                            icon: CupertinoIcons.heart_fill,
                            label: l10n.navFavorites,
                            onPressed: () async {
                              final now = DateTime.now();
                              if (_lastShuffleFavoritesTap != null &&
                                  now.difference(_lastShuffleFavoritesTap!) <
                                      const Duration(milliseconds: 1000)) {
                                return;
                              }
                              _lastShuffleFavoritesTap = now;
                              final favoriteCount = data.favorites.length;
                              if (favoriteCount > 0) {
                                await context
                                    .read<AppState>()
                                    .shuffleFavoriteTracks();
                              } else {
                                _showNoFavoritesDialog(context);
                              }
                            },
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Now playing card with liquid glass
                if (context.read<AppState>().audioHandler?.currentTrack != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildLiquidGlassNowPlayingCard(
                        context,
                        context.read<AppState>(),
                        l10n,
                      ),
                    ),
                  ),

                if (context.read<AppState>().audioHandler?.currentTrack != null)
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Continue listening section
                if (continueListeningAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildLiquidGlassSectionHeader(
                        l10n.continueListening,
                        CupertinoIcons.clock,
                        CupertinoColors.systemPurple,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: continueListeningAlbums.take(8).length,
                        itemExtent: 196, // 180 + 16 margin
                        cacheExtent: 400,
                        itemBuilder: (context, index) {
                          final album = continueListeningAlbums[index];
                          return _buildLiquidGlassAlbumCard(
                            context,
                            album,
                            context.read<AppState>(),
                            isLarge: true,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // Recently added section
                if (recentAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildLiquidGlassSectionHeader(
                        l10n.recentlyAdded,
                        CupertinoIcons.sparkles,
                        CupertinoColors.systemPink,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: recentAlbums.take(10).length,
                        itemExtent: 166, // 150 + 16 margin
                        cacheExtent: 400,
                        itemBuilder: (context, index) {
                          final album = recentAlbums[index];
                          return _buildLiquidGlassAlbumCard(
                            context,
                            album,
                            context.read<AppState>(),
                            isLarge: false,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // Made for you section
                if (madeForYouAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildLiquidGlassSectionHeader(
                        l10n.madeForYou,
                        CupertinoIcons.sparkles,
                        CupertinoColors.systemTeal,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: madeForYouAlbums.take(8).length,
                        itemExtent: 166, // 150 + 16 margin
                        cacheExtent: 400,
                        itemBuilder: (context, index) {
                          final album = madeForYouAlbums[index];
                          return _buildLiquidGlassAlbumCard(
                            context,
                            album,
                            context.read<AppState>(),
                            isLarge: false,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                // Favorites section
                if (similarToFavoritesAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildLiquidGlassSectionHeader(
                        l10n.yourFavorites,
                        CupertinoIcons.heart_fill,
                        CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: similarToFavoritesAlbums.take(8).length,
                        itemExtent: 166, // 150 + 16 margin
                        cacheExtent: 400,
                        itemBuilder: (context, index) {
                          final album = similarToFavoritesAlbums[index];
                          return _buildLiquidGlassAlbumCard(
                            context,
                            album,
                            context.read<AppState>(),
                            isLarge: false,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiquidGlassSectionHeader(
    String title,
    IconData icon,
    Color accentColor,
  ) {
    return Text(
      title,
      style: const TextStyle(
        color: CupertinoColors.white,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildLiquidGlassShuffleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: LiquidGlassMaterial(
        borderRadius: 16,
        tintColor: isPrimary ? CupertinoColors.systemPurple : null,
        tintOpacity: isPrimary ? 0.3 : 0.1,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary
                  ? CupertinoColors.white
                  : CupertinoColors.systemPink,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidGlassNowPlayingCard(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final currentTrack = appState.audioHandler?.currentTrack;
    if (currentTrack == null) return const SizedBox.shrink();

    return LiquidGlassMaterial(
      borderRadius: 20,
      tintColor: CupertinoColors.systemPurple,
      tintOpacity: 0.15,
      child: SizedBox(
        height: 130,
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Container(
                width: 130,
                height: 130,
                color: CupertinoColors.systemGrey6.darkColor,
                child: currentTrack.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.getImageUrl(
                          currentTrack.imageUrl!,
                          width: 300,
                          height: 300,
                        ),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_note,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_note,
                        size: 40,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            // Track info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.waveform,
                                color: CupertinoColors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.nowPlaying,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentTrack.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack.artistName ?? l10n.unknownArtist,
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Play button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidGlassAlbumCard(
    BuildContext context,
    Album album,
    AppState appState, {
    required bool isLarge,
  }) {
    final width = isLarge ? 180.0 : 150.0;
    final imageHeight = isLarge ? 180.0 : 130.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => DetailTrackView.album(album),
          ),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with liquid glass overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Container(
                    height: imageHeight,
                    width: width,
                    color: CupertinoColors.systemGrey6.darkColor,
                    child: album.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: appState.getImageUrl(
                              album.imageUrl!,
                              width: 400,
                              height: 400,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              CupertinoIcons.music_albums,
                              size: 50,
                              color: CupertinoColors.systemGrey,
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.music_albums,
                            size: 50,
                            color: CupertinoColors.systemGrey,
                          ),
                  ),
                  // Play indicator
                  if (isLarge)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: const Icon(
                              CupertinoIcons.play_fill,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Album info
            Text(
              album.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (album.artistName != null) ...[
              const SizedBox(height: 3),
              Text(
                album.artistName!,
                style: TextStyle(
                  color: CupertinoColors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
