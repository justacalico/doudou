import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../templates/page_template.dart';
import '../templates/music_cards.dart';
import '../../providers/app_state.dart';
import 'details/album_details.dart';
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
    return appState.jellyfinService.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: 'Home',
          actions: [
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
          child: appState.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your music library...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recently Added Albums section
                      SectionHeader(
                        title: 'Recently Added Albums',
                        subtitle: 'Your newest additions',
                        trailing: TextButton(
                          onPressed: () {},
                          child: const Text('View All'),
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: appState.albums.isEmpty
                            ? const Center(
                                child: Text('No albums found'),
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
                                      subtitle: album.artistName ?? 'Unknown Artist',
                                      imageUrl: _getImageUrl(appState, album.imageUrl),
                                      onTap: () {
                                        // Navigate to album details
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 32),

                      // Quick Access section
                      SectionHeader(
                        title: 'Quick Access',
                        subtitle: 'Jump back into your favorites',
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              'Liked Songs',
                              '${appState.tracks.where((t) => t.isFavorite).length} songs',
                              Icons.favorite,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              'All Albums',
                              '${appState.albums.length} albums',
                              Icons.album,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              'All Artists',
                              '${appState.artists.length} artists',
                              Icons.person,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Your Artists section
                      SectionHeader(
                        title: 'Your Artists',
                        subtitle: 'Browse by artist',
                        trailing: TextButton(
                          onPressed: () {},
                          child: const Text('View All'),
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: appState.artists.isEmpty
                            ? const Center(
                                child: Text('No artists found'),
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
                                      subtitle: 'Artist',
                                      imageUrl: _getImageUrl(appState, artist.imageUrl),
                                      onTap: () {
                                        // Navigate to artist details
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
                          title: 'Recent Tracks',
                          subtitle: 'Your music collection',
                        ),
                        
                        Column(
                          children: appState.tracks
                              .take(5)
                              .map((track) => MusicListTile(
                                    title: track.name,
                                    subtitle: '${track.artistName ?? 'Unknown Artist'} • ${track.albumName ?? 'Unknown Album'}',
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
