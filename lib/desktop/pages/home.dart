import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../templates/page_template.dart';
import '../templates/music_cards.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';

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
    final appState = context.read<AppState>();
    // Load library data when page loads
    appState.loadLibraryData();
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
                                      imageUrl: album.imageUrl != null
                                          ? appState.getImageUrl(album.imageUrl!)
                                          : null,
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
                    '247 songs',
                    Icons.favorite,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    'Downloaded',
                    '89 songs',
                    Icons.download,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    'Recently Added',
                    '23 songs',
                    Icons.new_releases,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Made for you section
            SectionHeader(
              title: 'Made For You',
              subtitle: 'Based on your listening habits',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: MusicCard(
                      title: 'Mix ${index + 1}',
                      subtitle: 'Auto-generated playlist',
                      onTap: () {
                        // Navigate to playlist
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Jump back in section
            SectionHeader(
              title: 'Jump Back In',
              subtitle: 'Pick up where you left off',
            ),
            
            Column(
              children: List.generate(5, (index) {
                return MusicListTile(
                  title: 'Song Title ${index + 1}',
                  subtitle: 'Artist Name • Album Name',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '3:${(20 + index * 7).toString().padLeft(2, '0')}',
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
                );
              }),
            ),

            const SizedBox(height: 100), // Extra space for bottom player
          ],
        ),
      ),
    );
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
