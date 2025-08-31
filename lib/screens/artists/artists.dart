import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.person_2, size: 64, color: CupertinoColors.systemGrey),
                SizedBox(height: 16),
                Text(
                  'No artists found',
                  style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          );
        }

        return Container(
          color: const Color(0xFF000000), // Dark background
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => appState.loadLibraryData(),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Dark card background
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: artist.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: appState.jellyfinService.getImageUrl(
                      artist.imageUrl!,
                      width: 100,
                      height: 100,
                    ),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF3A3A3C),
                      child: const Icon(CupertinoIcons.person, color: CupertinoColors.systemGrey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF3A3A3C),
                      child: const Icon(CupertinoIcons.person, color: CupertinoColors.systemGrey),
                    ),
                  )
                : Container(
                    color: const Color(0xFF3A3A3C),
                    child: const Icon(CupertinoIcons.person, color: CupertinoColors.systemGrey),
                  ),
          ),
        ),
        title: Text(
          artist.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: CupertinoColors.white, // White text
          ),
        ),
        trailing: const Icon(CupertinoIcons.forward, size: 16, color: CupertinoColors.systemGrey),
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
