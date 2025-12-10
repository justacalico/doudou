import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/apple_design/apple_theme.dart';
import '../templates/page_template.dart';
import '../templates/music_cards.dart';
import '../../providers/app_state.dart';
import 'details/media_details.dart';
import 'details/artist_details.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      // Load library data when page loads
      appState.loadLibraryData();
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    // Use the jellyfinService's image URL construction logic
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: l10n.navHome,
          actions: [
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refresh,
            ),
          ],
          child: appState.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.loadingYourMusicLibrary),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recently Added Albums section
                      SectionHeader(
                        title: l10n.recentlyAddedAlbums,
                        subtitle: l10n.yourNewestAdditions,
                        trailing: TextButton(
                          onPressed: () {},
                          child: Text(l10n.viewAll),
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: appState.albums.isEmpty
                            ? Center(
                                child: Text(l10n.noAlbumsFound),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: appState.albums.length > 10 
                                    ? 10 
                                    : appState.albums.length,
                                itemBuilder: (context, index) {
                                  final album = appState.albums[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: MusicCard(
                                      title: album.name,
                                      subtitle: album.artistName ?? l10n.unknownArtist,
                                      imageUrl: _getImageUrl(appState, album.imageUrl),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MediaDetailsPage.album(album: album),
                                              ),
                                            );
                                          },
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 32),

                      // Quick Access section
                      SectionHeader(
                        title: l10n.quickAccess,
                        subtitle: l10n.jumpBackIntoFavorites,
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              l10n.likedSongs,
                              l10n.countSongs(appState.tracks.where((t) => t.isFavorite).length),
                              Icons.favorite,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              l10n.allAlbums,
                              l10n.countAlbums(appState.albums.length),
                              Icons.album,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              l10n.allArtists,
                              l10n.countArtists(appState.artists.length),
                              Icons.person,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Your Artists section
                      SectionHeader(
                        title: l10n.yourArtists,
                        subtitle: l10n.browseByArtist,
                        trailing: TextButton(
                          onPressed: () {},
                          child: Text(l10n.viewAll),
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: appState.artists.isEmpty
                            ? Center(
                                child: Text(l10n.noArtistsFound),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: appState.artists.length > 10 
                                    ? 10 
                                    : appState.artists.length,
                                itemBuilder: (context, index) {
                                  final artist = appState.artists[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: MusicCard(
                                      title: artist.name,
                                      subtitle: l10n.artist,
                                      imageUrl: _getImageUrl(appState, artist.imageUrl),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ArtistDetailsPage(artist: artist),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 32),

                      // Recent Tracks section
                      if (appState.tracks.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentTracks,
                          subtitle: l10n.yourMusicCollection,
                        ),
                        
                        Column(
                          children: appState.tracks
                              .take(5)
                              .map((track) => MusicListTile(
                                    title: track.name,
                                    subtitle: '${track.artistName ?? l10n.unknownArtist} • ${track.albumName ?? l10n.unknownAlbum}',
                                    imageUrl: _getImageUrl(appState, track.imageUrl),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (track.duration != null)
                                          Text(
                                            _formatDuration(track.duration!),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        IconButton(
                                          onPressed: () {},
                                          icon: const Icon(Icons.more_vert),
                                          iconSize: 20,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      // Play song
                                    },
                                  ))
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 100), // Extra space for bottom player
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
