import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
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
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        _generateSuggestedSearches(appState);
      }
    }
  }

  void _generateSuggestedSearches(AppState appState) {
    // Generate suggested searches based on popular artists and recent albums
    final Set<String> suggestions = {};

    // Add top artists by track count
    final artistTrackCounts = <String, int>{};
    for (final track in appState.tracks) {
      if (track.artistName != null && track.artistName!.isNotEmpty) {
        artistTrackCounts[track.artistName!] =
            (artistTrackCounts[track.artistName!] ?? 0) + 1;
      }
    }

    final topArtists = artistTrackCounts.entries.toList()
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
      _recentSearches.removeWhere(
        (search) => search.toLowerCase() == query.toLowerCase(),
      );
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
      if (kDebugMode) {
        print('Failed to save recent searches: $e');
      }
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
      if (kDebugMode) {
        print('Failed to clear recent searches: $e');
      }
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
                // Enhanced Search Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF000000),
                        const Color(0xFF000000).withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with stats
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Search',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFFFFF),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${appState.tracks.length} songs • ${appState.albums.length} albums • ${appState.artists.length} artists',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.systemGrey
                                        .withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Search filters button (optional)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF3C3C3E).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.slider_horizontal_3,
                              color: CupertinoColors.systemGrey,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Enhanced Search Bar
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1C1C1E).withOpacity(0.8),
                              const Color(0xFF2C2C2E).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3C3C3E).withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withOpacity(0.2),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Search artists, albums, songs...',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          placeholderStyle: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: const Color(0x00000000),
                          onChanged: (value) => _performSearch(value, appState),
                          onSubmitted: (value) =>
                              _performSearch(value, appState),
                          autofocus: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content area with enhanced design
                Expanded(child: _buildSearchContent(appState)),
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
        child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
      );
    }

    // Check if we have any results
    final hasResults =
        _trackResults.isNotEmpty ||
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
    if (_recentSearches.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // Enhanced empty state
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF007AFF).withOpacity(0.15),
                    const Color(0xFF5856D6).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                CupertinoIcons.search,
                size: 56,
                color: Color(0xFF007AFF),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Discover Your Music',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Search through your entire music library\nto find exactly what you\'re looking for',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Popular suggestions with enhanced design
            if (appState.artists.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1C1C1E).withOpacity(0.8),
                      const Color(0xFF2C2C2E).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3C3C3E).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.sparkles,
                          color: Color(0xFFFF9F0A),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Popular in your library',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: appState.artists
                          .take(6)
                          .map(
                            (artist) => GestureDetector(
                              onTap: () {
                                _searchController.text = artist.name;
                                _performSearch(artist.name, appState);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF007AFF).withOpacity(0.15),
                                      const Color(0xFF5856D6).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  artist.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced section header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent searches',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3C3C3E).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced recent searches list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    _searchController.text = search;
                    _performSearch(search, appState);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1C1C1E).withOpacity(0.6),
                          const Color(0xFF2C2C2E).withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3C3C3E).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            CupertinoIcons.search,
                            color: Color(0xFF007AFF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            search,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                        // Individual delete button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _recentSearches.removeAt(index);
                            });
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setStringList(
                                'recent_searches',
                                _recentSearches,
                              );
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              color: CupertinoColors.systemGrey2,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedResults(AppState appState) {
    List<Widget> allResults = [];

    // Add section headers and results with enhanced design
    if (_artistResults.isNotEmpty) {
      allResults.add(
        _buildSectionHeader(
          'Artists',
          _artistResults.length,
          CupertinoIcons.person_2,
        ),
      );
      for (final artist in _artistResults.take(5)) {
        allResults.add(_buildUnifiedArtistItem(artist, appState));
      }
      if (_artistResults.length > 5) {
        allResults.add(
          _buildShowMoreButton(
            'Show ${_artistResults.length - 5} more artists',
          ),
        );
      }
    }

    if (_albumResults.isNotEmpty) {
      if (allResults.isNotEmpty) allResults.add(const SizedBox(height: 24));
      allResults.add(
        _buildSectionHeader(
          'Albums',
          _albumResults.length,
          CupertinoIcons.music_albums,
        ),
      );
      for (final album in _albumResults.take(5)) {
        allResults.add(_buildUnifiedAlbumItem(album, appState));
      }
      if (_albumResults.length > 5) {
        allResults.add(
          _buildShowMoreButton('Show ${_albumResults.length - 5} more albums'),
        );
      }
    }

    if (_trackResults.isNotEmpty) {
      if (allResults.isNotEmpty) allResults.add(const SizedBox(height: 24));
      allResults.add(
        _buildSectionHeader(
          'Songs',
          _trackResults.length,
          CupertinoIcons.music_note,
        ),
      );
      for (final track in _trackResults.take(8)) {
        allResults.add(_buildUnifiedTrackItem(track, appState));
      }
      if (_trackResults.length > 8) {
        allResults.add(
          _buildShowMoreButton('Show ${_trackResults.length - 8} more songs'),
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: allResults.length + 1, // +1 for bottom padding
      itemBuilder: (context, index) {
        if (index == allResults.length) {
          return const SizedBox(
            height: 150,
          ); // Bottom padding for mini player + nav bar
        }
        return allResults[index];
      },
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF007AFF).withOpacity(0.15),
                  const Color(0xFF5856D6).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF007AFF), size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: GestureDetector(
        onTap: () {
          // TODO: Implement show more functionality
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E).withOpacity(0.6),
                const Color(0xFF2C2C2E).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF007AFF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.chevron_down,
                color: Color(0xFF007AFF),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced unified result item builders
  Widget _buildUnifiedArtistItem(Artist artist, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E).withOpacity(0.6),
                const Color(0xFF2C2C2E).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF3C3C3E).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Enhanced artist avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8E4EC6).withOpacity(0.8),
                      const Color(0xFFBF5AF2).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8E4EC6).withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: artist.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(
                            artist.imageUrl!,
                            width: 112,
                            height: 112,
                          ),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF8E4EC6).withOpacity(0.8),
                                  const Color(0xFFBF5AF2).withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              color: Color(0xFFFFFFFF),
                              size: 28,
                            ),
                          ),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.person_fill,
                        color: Color(0xFFFFFFFF),
                        size: 28,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E4EC6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Artist',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E4EC6),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildUnifiedAlbumItem(Album album, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => DetailTrackView.album(album),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E).withOpacity(0.6),
                const Color(0xFF2C2C2E).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF3C3C3E).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Enhanced album artwork
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF30D158).withOpacity(0.8),
                      const Color(0xFF32ADE6).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF30D158).withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: album.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(
                            album.imageUrl!,
                            width: 112,
                            height: 112,
                          ),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF30D158).withOpacity(0.8),
                                  const Color(0xFF32ADE6).withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              color: Color(0xFFFFFFFF),
                              size: 28,
                            ),
                          ),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        color: Color(0xFFFFFFFF),
                        size: 28,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF30D158).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Album',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF30D158),
                            ),
                          ),
                        ),
                        if (album.artistName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              album.artistName!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildUnifiedTrackItem(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => appState.playTrack(track),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E).withOpacity(0.4),
                const Color(0xFF2C2C2E).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3C3C3E).withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Enhanced track artwork
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF007AFF).withOpacity(0.8),
                      const Color(0xFF5856D6).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: track.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedImageWidget(
                          imageUrl: appState.getImageUrl(
                            track.imageUrl!,
                            width: 96,
                            height: 96,
                          ),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF007AFF).withOpacity(0.8),
                                  const Color(0xFF5856D6).withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFFFFFFFF),
                              size: 20,
                            ),
                          ),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_note,
                        color: Color(0xFFFFFFFF),
                        size: 20,
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
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName ?? 'Unknown Artist',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Track actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (track.isFavorite)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        color: Color(0xFFFF453A),
                        size: 16,
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      color: Color(0xFF007AFF),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
