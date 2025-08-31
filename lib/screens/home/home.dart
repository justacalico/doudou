import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../albums/details/album_details.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Create different shuffled lists for variety
        final allAlbums = List<Album>.from(appState.albums);
        final shuffledAlbums = List<Album>.from(allAlbums)..shuffle();
        final recentAlbums = allAlbums.take(6).toList();
        final continueListeningAlbums = shuffledAlbums.take(4).toList();
        final madeForYouAlbums = allAlbums.length > 10 
            ? allAlbums.skip(6).take(4).toList() 
            : shuffledAlbums.skip(2).take(4).toList();
        
        return Container(
          color: const Color(0xFF000000),
          child: CustomScrollView(
            slivers: [
              // Home header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Home',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
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
                      const Text(
                        'Recently added albums',
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
                    itemCount: appState.albums.length > 4 ? 4 : appState.albums.length,
                    itemBuilder: (context, index) {
                      final album = appState.albums[index];
                      return _buildAlbumCard(context, album, appState);
                    },
                  ),
                ),
              ),
              
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
