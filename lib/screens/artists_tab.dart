import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_state.dart';
import '../models/jellyfin_models.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.artists.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (appState.artists.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.person_2, size: 64, color: CupertinoColors.secondaryLabel),
                SizedBox(height: 16),
                Text(
                  'No artists found',
                  style: TextStyle(fontSize: 18, color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
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
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
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
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
                      child: const Icon(CupertinoIcons.person),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
                      child: const Icon(CupertinoIcons.person),
                    ),
                  )
                : Container(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    child: const Icon(CupertinoIcons.person),
                  ),
          ),
        ),
        title: Text(
          artist.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(CupertinoIcons.forward, size: 16),
        onTap: () {
          // TODO: Navigate to artist detail screen
          _showAlert(context, artist.name);
        },
      ),
    );
  }

  void _showAlert(BuildContext context, String artistName) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Coming Soon'),
        content: Text('Artist detail for $artistName - Coming soon!'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
