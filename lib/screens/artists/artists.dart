import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../widgets/mini_player.dart';
import 'artist_detail.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.artists.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

        if (appState.artists.isEmpty) {
          return Container(
            color: const Color(0xFF000000), // Pure black for OLED
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.person_2,
                    size: 80,
                    color: Color(0xFF333333),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No artists found',
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
                      'Your music artists will appear here once they are loaded from your Jellyfin server.',
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
          color: const Color(0xFF000000), // Pure black background for OLED
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
                                  color: const Color(0xFF32D74B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF32D74B).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_2_fill,
                                  color: Color(0xFF32D74B),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Artists',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${appState.artists.length} artist${appState.artists.length == 1 ? '' : 's'}',
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
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final artist = appState.artists[index];
                        return ArtistCard(artist: artist);
                      },
                      childCount: appState.artists.length,
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

class ArtistCard extends StatelessWidget {
  final Artist artist;

  const ArtistCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoListTile(
        backgroundColor: Colors.transparent,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1C1C1E),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: artist.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: appState.jellyfinService.getImageUrl(
                      artist.imageUrl!,
                      width: 112,
                      height: 112,
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
                        CupertinoIcons.person,
                        color: Color(0xFF8E8E93),
                        size: 28,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF1C1C1E),
                    child: const Icon(
                      CupertinoIcons.person,
                      color: Color(0xFF8E8E93),
                      size: 28,
                    ),
                  ),
          ),
        ),
        title: Text(
          artist.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF), // Pure white text
            fontSize: 16,
            height: 1.2,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
      ),
    );
  }
}
