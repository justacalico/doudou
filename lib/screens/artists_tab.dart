import 'package:flutter/material.dart';
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
            child: CircularProgressIndicator(),
          );
        }

        if (appState.artists.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No artists found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => appState.loadLibraryData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appState.artists.length,
            itemBuilder: (context, index) {
              final artist = appState.artists[index];
              return ArtistCard(artist: artist);
            },
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: artist.imageUrl != null
              ? CachedNetworkImageProvider(
                  appState.jellyfinService.getImageUrl(
                    artist.imageUrl!,
                    width: 100,
                    height: 100,
                  ),
                )
              : null,
          child: artist.imageUrl == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(
          artist.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: Navigate to artist detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Artist detail for ${artist.name} - Coming soon!'),
            ),
          );
        },
      ),
    );
  }
}
