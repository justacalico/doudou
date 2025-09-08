import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    if (favoriteTracks.isEmpty) {
      // If no favorites, return recently added albums
      return allAlbums.take(6).toList();
    }

    // Get albums from favorite artists
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    final albumsByFavoriteArtists = allAlbums
        .where((album) => 
            album.artistName != null && 
            favoriteArtistNames.contains(album.artistName!))
        .toList()
      ..shuffle();

    // Mix with some random albums
    final otherAlbums = allAlbums
        .where((album) => 
            album.artistName == null || 
            !favoriteArtistNames.contains(album.artistName!))
        .toList()
      ..shuffle();

    final recommended = <Album>[];
    recommended.addAll(albumsByFavoriteArtists.take(4));
    recommended.addAll(otherAlbums.take(2));
    
    return recommended.take(6).toList();
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
        final shuffledAlbums = _shuffledAlbums ?? allAlbums;
        final continueListeningAlbums = _continueListeningAlbums ?? allAlbums.take(4).toList();
        final madeForYouAlbums = _madeForYouAlbums ?? allAlbums.take(4).toList();
        final similarToFavoritesAlbums = _similarToFavoritesAlbums ?? [];
        
        return Container(
          color: const Color(0xFF000000),
          child: CustomScrollView(
            slivers: [
              // Home header with profile and notification icons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 0),
                  child: Row(
                    children: [
                      // MANET+ Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'MANET+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Home',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Notification and Profile icons
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1C1C1E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.bell,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE91E63),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              
              // Listen now section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with shuffle buttons
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                await appState.shuffleAllTracks();
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B2635),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.shuffle, color: CupertinoColors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Shuffle all',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final favoriteCount = appState.favoriteTracks.length;
                                if (favoriteCount > 0) {
                                  await appState.shuffleFavoriteTracks();
                                } else {
                                  // Show a message if no favorites
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
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B2635),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.heart, color: CupertinoColors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Shuffle favorites',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      
                      // Listen now section
                      const Text(
                        'Listen now',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Featured album card
                      if (shuffledAlbums.isNotEmpty)
                        _buildFeaturedCard(context, shuffledAlbums.first, appState),
                      
                      const SizedBox(height: 30),
                      
                      // Recently added albums
                      Text(
                        favoriteTracks.isNotEmpty ? 'Recommended for you' : 'Recently added albums',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 24,
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
                    itemCount: recentAlbums.length,
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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Continue listening grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: continueListeningAlbums.length,
                        itemBuilder: (context, index) {
                          final album = continueListeningAlbums[index];
                          return _buildContinueListeningCard(context, album, appState);
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Made for you section
                      const Text(
                        'Made for you',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Made for you horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: madeForYouAlbums.length,
                    itemBuilder: (context, index) {
                      final album = madeForYouAlbums[index];
                      return _buildAlbumCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
              // Similar to favorites section (only show if user has favorites)
              if (similarToFavoritesAlbums.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'More from your favorite artists',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: similarToFavoritesAlbums.length,
                      itemBuilder: (context, index) {
                        final album = similarToFavoritesAlbums[index];
                        return _buildAlbumCard(context, album, appState);
                      },
                    ),
                  ),
                ),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for mini player
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Album album, AppState appState) {
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
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A365D),
              const Color(0xFF2D3748),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Album art
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: album.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 300,
                            height: 300,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF2D2D2D),
                            child: const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF2D2D2D),
                            child: const Icon(CupertinoIcons.music_albums, size: 64),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF2D2D2D),
                          child: const Icon(CupertinoIcons.music_albums, size: 64),
                        ),
                ),
              ),
            ),
            // Info and play button
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.artistName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        album.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Container(
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
                  ],
                ),
              ),
            ),
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

  Widget _buildContinueListeningCard(BuildContext context, Album album, AppState appState) {
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
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: Container(
                width: 60,
                height: double.infinity,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.jellyfinService.getImageUrl(
                          album.imageUrl!,
                          width: 200,
                          height: 200,
                        ),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 30,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 30,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
