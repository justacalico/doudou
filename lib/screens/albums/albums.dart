import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/cached_image.dart';
import 'details/album_details.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.albums.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

        if (appState.albums.isEmpty) {
          return Container(
            color: const Color(0xFF000000), // Pure black for OLED
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_albums,
                    size: 80,
                    color: Color(0xFF333333),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No albums found',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Your music albums will appear here once they are loaded from your Jellyfin server.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: const Color(0xFF000000), // Dark background
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () => appState.loadLibraryData(),
                  ),
                  // Header section
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.music_albums_fill,
                                  color: Color(0xFF007AFF),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Albums',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${appState.albums.length} album${appState.albums.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = appState.albums[index];
                          return AlbumCard(album: album);
                        },
                        childCount: appState.albums.length,
                      ),
                    ),
                  ),
                  // Add bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
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
}

class AlbumCard extends StatelessWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
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
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF000000), // Pure black background
          border: Border.all(
            color: const Color(0xFF1C1C1E),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: album.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 300,
                            height: 300,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Center(
                              child: CupertinoActivityIndicator(
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              size: 64,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1C1C1E),
                          child: const Icon(
                            CupertinoIcons.music_albums,
                            size: 64,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  color: const Color(0xFF000000), // Pure black background for text area
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        album.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFFFFFFFF), // White text
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (album.artistName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          album.artistName!,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            height: 1.2,
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
                            color: Color(0xFF8E8E93),
                            fontSize: 11,
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
      ),
    );
  }
}
