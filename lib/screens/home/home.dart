import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../albums/details/album_details.dart';

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

  void _initializeAlbumLists(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (_shuffledAlbums == null || _shuffledAlbums!.isEmpty) {
      _shuffledAlbums = List<Album>.from(allAlbums)..shuffle();
      
      // Get personalized recommendations based on favorites
      _recommendedAlbums = _getRecommendedAlbums(allAlbums, favoriteTracks);
      _continueListeningAlbums = _getContinueListeningAlbums(allAlbums, favoriteTracks);
      _madeForYouAlbums = _getMadeForYouAlbums(allAlbums, favoriteTracks);
      _similarToFavoritesAlbums = _getSimilarToFavoritesAlbums(allAlbums, favoriteTracks);
    }
  }

  List<Album> _getRecommendedAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
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

  List<Album> _getContinueListeningAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (favoriteTracks.isEmpty) {
      return List<Album>.from(allAlbums)..shuffle();
    }

    // Get albums that contain favorite tracks
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final favoriteAlbums = allAlbums
        .where((album) => favoriteAlbumIds.contains(album.id))
        .toList();

    // If we have enough favorite albums, use them
    if (favoriteAlbums.length >= 4) {
      favoriteAlbums.shuffle();
      return favoriteAlbums.take(4).toList();
    }

    // Otherwise, mix favorite albums with similar ones
    final otherAlbums = allAlbums
        .where((album) => !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    final continueListening = <Album>[];
    continueListening.addAll(favoriteAlbums);
    continueListening.addAll(otherAlbums.take(4 - favoriteAlbums.length));
    
    return continueListening;
  }

  List<Album> _getMadeForYouAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (favoriteTracks.isEmpty) {
      return allAlbums.length > 10 
          ? allAlbums.skip(6).take(4).toList() 
          : List<Album>.from(allAlbums)..shuffle();
    }

    // Get albums from artists that appear in favorites
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    final albumsByFavoriteArtists = allAlbums
        .where((album) => 
            album.artistName != null && 
            favoriteArtistNames.contains(album.artistName!))
        .toList();

    // Remove albums that contain favorite tracks (to avoid duplicates with continue listening)
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final madeForYou = albumsByFavoriteArtists
        .where((album) => !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    if (madeForYou.length >= 4) {
      return madeForYou.take(4).toList();
    }

    // Fill with other albums if needed
    final otherAlbums = allAlbums
        .where((album) => 
            (album.artistName == null || !favoriteArtistNames.contains(album.artistName!)) &&
            !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    madeForYou.addAll(otherAlbums.take(4 - madeForYou.length));
    return madeForYou;
  }

  List<Album> _getSimilarToFavoritesAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
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

    final similarAlbums = allAlbums
        .where((album) => 
            album.artistName != null && 
            favoriteArtistNames.contains(album.artistName!) &&
            !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    return similarAlbums.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final allAlbums = List<Album>.from(appState.albums);
        final favoriteTracks = List<Track>.from(appState.favoriteTracks);
        _initializeAlbumLists(allAlbums, favoriteTracks);
        
        final recentAlbums = _recommendedAlbums ?? allAlbums.take(6).toList();
        final continueListeningAlbums = _continueListeningAlbums ?? allAlbums.take(4).toList();
        final madeForYouAlbums = _madeForYouAlbums ?? allAlbums.take(4).toList();
        final similarToFavoritesAlbums = _similarToFavoritesAlbums ?? [];
        
        return Container(
          color: const Color(0xFF000000),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Shuffle buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 600;
                      
                      if (isDesktop) {
                        // Desktop layout: centered buttons with better spacing
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildShuffleButton(
                                    icon: CupertinoIcons.shuffle,
                                    label: 'Shuffle all',
                                    onPressed: () async {
                                      await appState.shuffleAllTracks();
                                    },
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildShuffleButton(
                                    icon: CupertinoIcons.heart,
                                    label: 'Shuffle favorites',
                                    onPressed: () async {
                                      final favoriteCount = appState.favoriteTracks.length;
                                      if (favoriteCount > 0) {
                                        await appState.shuffleFavoriteTracks();
                                      } else {
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (BuildContext context) => CupertinoAlertDialog(
                                            title: const Text('No Favorites'),
                                            content: const Text('You haven\'t marked any songs as favorites yet. Add some favorites to use this shuffle option.'),
                                            actions: <CupertinoDialogAction>[
                                              CupertinoDialogAction(
                                                child: const Text('OK'),
                                                onPressed: () => Navigator.of(context).pop(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    isPrimary: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Mobile layout: scrollable horizontal buttons
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 180,
                                child: _buildShuffleButton(
                                  icon: CupertinoIcons.shuffle,
                                  label: 'Shuffle all',
                                  onPressed: () async {
                                    await appState.shuffleAllTracks();
                                  },
                                  isPrimary: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 180,
                                child: _buildShuffleButton(
                                  icon: CupertinoIcons.heart,
                                  label: 'Shuffle favorites',
                                  onPressed: () async {
                                    final favoriteCount = appState.favoriteTracks.length;
                                    if (favoriteCount > 0) {
                                      await appState.shuffleFavoriteTracks();
                                    } else {
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (BuildContext context) => CupertinoAlertDialog(
                                          title: const Text('No Favorites'),
                                          content: const Text('You haven\'t marked any songs as favorites yet. Add some favorites to use this shuffle option.'),
                                          actions: <CupertinoDialogAction>[
                                            CupertinoDialogAction(
                                              child: const Text('OK'),
                                              onPressed: () => Navigator.of(context).pop(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  isPrimary: false,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Recently added albums
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recently added albums',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Recently added albums horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentAlbums.take(6).length,
                    itemBuilder: (context, index) {
                      final album = recentAlbums[index];
                      return _buildAlbumCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Continue listening section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue listening',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Continue listening horizontal scroll with larger cards
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: continueListeningAlbums.take(4).length,
                    itemBuilder: (context, index) {
                      final album = continueListeningAlbums[index];
                      return _buildLargeContinueListeningCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Listen now section
              if (appState.audioHandler?.currentTrack != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Listen now',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildListenNowCard(context, appState),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              
              // Recent playlists section (using Made for you albums as placeholder)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent playlists',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Recent playlists horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: madeForYouAlbums.take(6).length,
                    itemBuilder: (context, index) {
                      final album = madeForYouAlbums[index];
                      return _buildPlaylistCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Favorite albums section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Favorite albums',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Favorite albums horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: similarToFavoritesAlbums.take(6).length,
                    itemBuilder: (context, index) {
                      final album = similarToFavoritesAlbums[index];
                      return _buildFavoriteAlbumCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 150)), // Space for mini player (70px) + nav bar (65px) + extra padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildLargeContinueListeningCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1C1C1E),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 180,
                width: 180,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          album.imageUrl!,
                          width: 400,
                          height: 400,
                        ),
                        fit: BoxFit.cover,
                        width: 180,
                        height: 180,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 60,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 60,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        album.name,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (album.artistName != null) ...[
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          album.artistName!,
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListenNowCard(BuildContext context, AppState appState) {
    final currentTrack = appState.audioHandler?.currentTrack;
    if (currentTrack == null) return Container();

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1C1C1E),
      ),
      child: Row(
        children: [
          // Album art
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              width: 120,
              height: 120,
              color: const Color(0xFF2D2D2D),
              child: currentTrack.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: appState.jellyfinService.getImageUrl(
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
          // Track info and play button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentTrack.artistName ?? 'Unknown Artist',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTrack.name,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
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
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFE91E63),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                color: CupertinoColors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                width: 120,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          album.imageUrl!,
                          width: 300,
                          height: 300,
                        ),
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 40,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteAlbumCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 160,
                width: 160,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          album.imageUrl!,
                          width: 400,
                          height: 400,
                        ),
                        fit: BoxFit.cover,
                        width: 160,
                        height: 160,
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
            ),
            const SizedBox(height: 12),
            Text(
              album.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (album.artistName != null) ...[
              const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 140,
                width: 140,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          album.imageUrl!,
                          width: 300,
                          height: 300,
                        ),
                        fit: BoxFit.cover,
                        width: 140,
                        height: 140,
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
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (album.artistName != null)
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
        ),
      ),
    );
  }

  Widget _buildShuffleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 56, // Slightly taller for desktop
        decoration: BoxDecoration(
          color: isPrimary 
              ? const Color(0xFFE91E63).withOpacity(0.12)
              : const Color(0xFFE91E63).withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFE91E63).withOpacity(0.3)
                : const Color(0xFFE91E63).withOpacity(0.15),
            width: 1,
          ),
          // Enhanced shadow for desktop
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isPrimary
                  ? const Color(0xFFE91E63)
                  : const Color(0xFFE91E63).withOpacity(0.8), 
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? const Color(0xFFE91E63)
                    : const Color(0xFFE91E63).withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}