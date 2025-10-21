import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../artists/details/artist_detail.dart';
import '../shared/detail_track_view.dart';
import '../../widgets/cached_image_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Search results by category
  List<Track> _trackResults = [];
  List<Album> _albumResults = [];
  List<Artist> _artistResults = [];
  List<Playlist> _playlistResults = [];
  
  // Recent searches
  List<String> _recentSearches = [];
  
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load recent searches after the widget is built to access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSearches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSearches = prefs.getStringList('recent_searches') ?? [];
      
      setState(() {
        _recentSearches = savedSearches;
      });
    } catch (e) {
      // If SharedPreferences fails, populate with popular artists/albums from library
      final appState = Provider.of<AppState>(context, listen: false);
      _generateSuggestedSearches(appState);
    }
  }

  void _generateSuggestedSearches(AppState appState) {
    // Generate suggested searches based on popular artists and recent albums
    final Set<String> suggestions = {};
    
    // Add top artists by track count
    final artistTrackCounts = <String, int>{};
    for (final track in appState.tracks) {
      if (track.artistName != null && track.artistName!.isNotEmpty) {
        artistTrackCounts[track.artistName!] = (artistTrackCounts[track.artistName!] ?? 0) + 1;
      }
    }
    
    final topArtists = artistTrackCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    // Add top 5 artists
    for (final entry in topArtists.take(5)) {
      suggestions.add(entry.key);
    }
    
    // Add recent album names (first 3-4)
    for (final album in appState.albums.take(4)) {
      if (album.name.isNotEmpty) {
        suggestions.add(album.name);
      }
    }
    
    setState(() {
      _recentSearches = suggestions.take(10).toList();
    });
  }

  void _addToRecentSearches(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _recentSearches.removeWhere((search) => search.toLowerCase() == query.toLowerCase());
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
    });
    
    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', _recentSearches);
    } catch (e) {
      print('Failed to save recent searches: $e');
    }
  }

  void _performSearch(String query, AppState appState) async {
    if (query.trim().isEmpty) {
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _artistResults = [];
        _playlistResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    // Add to recent searches when performing search
    _addToRecentSearches(query);

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final searchTerm = query.toLowerCase();
      
      // Search tracks
      final trackResults = appState.tracks.where((track) {
        final trackName = track.name.toLowerCase();
        final artistName = track.artistName?.toLowerCase() ?? '';
        final albumName = track.albumName?.toLowerCase() ?? '';
        
        return trackName.contains(searchTerm) ||
               artistName.contains(searchTerm) ||
               albumName.contains(searchTerm);
      }).toList();

      // Search albums
      final albumResults = appState.albums.where((album) {
        final albumName = album.name.toLowerCase();
        final artistName = album.artistName?.toLowerCase() ?? '';
        
        return albumName.contains(searchTerm) ||
               artistName.contains(searchTerm);
      }).toList();

      // Search artists
      final artistResults = appState.artists.where((artist) {
        final artistName = artist.name.toLowerCase();
        
        return artistName.contains(searchTerm);
      }).toList();

      // Search playlists
      final playlistResults = appState.playlists.where((playlist) {
        final playlistName = playlist.name.toLowerCase();
        
        return playlistName.contains(searchTerm);
      }).toList();

      setState(() {
        _trackResults = trackResults;
        _albumResults = albumResults;
        _artistResults = artistResults;
        _playlistResults = playlistResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _trackResults = [];
        _albumResults = [];
        _artistResults = [];
        _playlistResults = [];
        _isSearching = false;
      });
    }
  }

  void _clearRecentSearches() async {
    setState(() {
      _recentSearches.clear();
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
    } catch (e) {
      print('Failed to clear recent searches: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Pure black for OLED
          resizeToAvoidBottomInset: true,
          child: SafeArea(
            child: Column(
              children: [
                // Search Header with just search bar
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
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Artists, albums, songs, or playlists',
                          style: const TextStyle(color: Color(0xFFFFFFFF)),
                          placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey2),
                          backgroundColor: const Color(0x00000000),
                          onChanged: (value) => _performSearch(value, appState),
                          onSubmitted: (value) => _performSearch(value, appState),
                          autofocus: false,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content area
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
      return _buildRecentSearches(appState);
    }

    if (_isSearching) {
      return const Center(
        child: CupertinoActivityIndicator(
          color: Color(0xFFFFFFFF),
        ),
      );
    }

    // Check if we have any results
    final hasResults = _trackResults.isNotEmpty || 
                       _albumResults.isNotEmpty || 
                       _artistResults.isNotEmpty || 
                       _playlistResults.isNotEmpty;

    if (!hasResults) {
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
          ],
        ),
      );
    }

    return _buildUnifiedResults(appState);
  }

  Widget _buildRecentSearches(AppState appState) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recentSearches.length,
      itemBuilder: (context, index) {
        final search = _recentSearches[index];
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            _searchController.text = search;
            _performSearch(search, appState);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.clock,
                  color: CupertinoColors.systemGrey2,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    search,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnifiedResults(AppState appState) {
    List<Widget> allResults = [];

    // Add artists first (highest priority)
    for (final artist in _artistResults) {
      allResults.add(_buildUnifiedArtistItem(artist, appState));
    }

    // Add albums second
    for (final album in _albumResults) {
      allResults.add(_buildUnifiedAlbumItem(album, appState));
    }

    // Add tracks last
    for (final track in _trackResults) {
      allResults.add(_buildUnifiedTrackItem(track, appState));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allResults.length + 1, // +1 for bottom padding
      itemBuilder: (context, index) {
        if (index == allResults.length) {
          return const SizedBox(height: 150); // Bottom padding for mini player + nav bar
        }
        return allResults[index];
      },
    );
  }

  // Unified result item builders (no section headers)
  Widget _buildUnifiedArtistItem(Artist artist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Artist avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: artist.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(artist.imageUrl!, width: 100, height: 100),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E4EC6),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              color: Color(0xFFFFFFFF),
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E4EC6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Artist',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedAlbumItem(Album album, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => DetailTrackView.album(album),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Album artwork
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: album.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(album.imageUrl!, width: 100, height: 100),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              color: Color(0xFFFFFFFF),
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_albums,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
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
                      'Album • ${album.artistName ?? 'Unknown Artist'}',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedTrackItem(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => appState.playTrack(track),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Track artwork
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: track.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(track.imageUrl!, width: 100, height: 100),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFFFFFFFF),
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
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
                      track.artistName ?? 'Unknown Artist',
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
              // Track actions
              if (track.isFavorite)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: Color(0xFFFF453A),
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}