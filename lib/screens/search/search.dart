import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query, AppState appState) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Search through all tracks for matches
      final allTracks = appState.tracks;
      final results = allTracks.where((track) {
        final trackName = track.name.toLowerCase();
        final artistName = track.artistName?.toLowerCase() ?? '';
        final albumName = track.albumName?.toLowerCase() ?? '';
        final searchTerm = query.toLowerCase();
        
        return trackName.contains(searchTerm) ||
               artistName.contains(searchTerm) ||
               albumName.contains(searchTerm);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Pure black for OLED
          child: SafeArea(
            child: Column(
              children: [
                // Search Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Songs, artists, or albums',
                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                        placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey2),
                        backgroundColor: const Color(0xFF1C1C1E),
                        onChanged: (value) => _performSearch(value, appState),
                        onSubmitted: (value) => _performSearch(value, appState),
                      ),
                    ],
                  ),
                ),
                
                // Search Results
                Expanded(
                  child: _buildSearchContent(appState),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchContent(AppState appState) {
    if (_searchQuery.isEmpty) {
      return _buildSearchSuggestions(appState);
    }

    if (_isSearching) {
      return const Center(
        child: CupertinoActivityIndicator(
          color: Color(0xFFFFFFFF),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.search,
              size: 64,
              color: CupertinoColors.systemGrey2,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 18,
                color: CupertinoColors.systemGrey2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for something else',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return _buildTrackTile(track, appState);
      },
    );
  }

  Widget _buildSearchSuggestions(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          
          // Browse Categories
          _buildBrowseCategory(
            icon: CupertinoIcons.music_note_2,
            title: 'Recently Played',
            subtitle: 'Your recent tracks',
            color: const Color(0xFF007AFF),
            onTap: () {
              _showRecentlyPlayed(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.heart_fill,
            title: 'Liked Songs',
            subtitle: 'Your favorite tracks',
            color: const Color(0xFFFF453A),
            onTap: () {
              _showFavorites(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.music_albums,
            title: 'Albums',
            subtitle: 'Browse all albums',
            color: const Color(0xFF30D158),
            onTap: () {
              _showAlbums(context, appState);
            },
          ),
          _buildBrowseCategory(
            icon: CupertinoIcons.person_2,
            title: 'Artists',
            subtitle: 'Browse all artists',
            color: const Color(0xFFFF9F0A),
            onTap: () {
              // TODO: Navigate to artists
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseCategory({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFFFFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackTile(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          // Play the track
          await appState.playTrack(track);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Album Art
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFF2C2C2E),
                  child: track.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            track.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey2,
                              size: 20,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.music_note,
                          color: CupertinoColors.systemGrey2,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Track Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artistName ?? "Unknown Artist"}${track.albumName != null ? " • ${track.albumName}" : ""}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // More Options
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  // TODO: Show track options (add to playlist, etc.)
                },
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.systemGrey2,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
