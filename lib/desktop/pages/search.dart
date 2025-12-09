import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import 'details/media_details.dart';
import 'details/artist_details.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, tracks, albums, artists, playlists
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-focus the search field when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty || appState.artists.isEmpty || appState.tracks.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  Map<String, List<dynamic>> _getSearchResults(AppState appState) {
    if (_searchQuery.isEmpty) {
      return {
        'tracks': [],
        'albums': [],
        'artists': [],
        'playlists': [],
      };
    }

    // Browse all mode - show all items
    if (_searchQuery == '*') {
      return {
        'tracks': appState.tracks,
        'albums': appState.albums,
        'artists': appState.artists,
        'playlists': appState.playlists,
      };
    }

    final query = _searchQuery.toLowerCase();

    final tracks = appState.tracks.where((track) {
      return track.name.toLowerCase().contains(query) ||
             (track.artistName?.toLowerCase().contains(query) ?? false) ||
             (track.albumName?.toLowerCase().contains(query) ?? false);
    }).toList();

    final albums = appState.albums.where((album) {
      return album.name.toLowerCase().contains(query) ||
             (album.artistName?.toLowerCase().contains(query) ?? false);
    }).toList();

    final artists = appState.artists.where((artist) {
      return artist.name.toLowerCase().contains(query);
    }).toList();

    final playlists = appState.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(query);
    }).toList();

    return {
      'tracks': tracks,
      'albums': albums,
      'artists': artists,
      'playlists': playlists,
    };
  }

  int _getTotalResults(Map<String, List<dynamic>> results) {
    return results.values.fold(0, (sum, list) => sum + list.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final searchResults = _getSearchResults(appState);
        final totalResults = _getTotalResults(searchResults);
        
        return PageTemplate(
          title: l10n.navSearch,
          actions: [
            // Clear search button
            if (_searchQuery.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'all';
                  });
                  _searchFocusNode.requestFocus();
                },
                icon: const Icon(Icons.clear),
                label: Text(l10n.clear),
              ),
          ],
          child: Column(
            children: [
              // Search bar
              _buildSearchBar(l10n),
              
              const SizedBox(height: 16),
              
              // Filter chips
              _buildFilterChips(searchResults, l10n),
              
              const SizedBox(height: 16),
              
              // Results or initial state
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildInitialState(appState, l10n)
                    : totalResults == 0
                        ? _buildNoResults(l10n)
                        : _buildSearchResults(appState, searchResults, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: l10n.searchPlaceholder,
            prefixIcon: const Icon(Icons.search, size: 28),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: theme.textTheme.titleMedium,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSubmitted: (value) {
            // Optional: Handle search submission
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(Map<String, List<dynamic>> results, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text('${l10n.all} (${_getTotalResults(results)})'),
            selected: _selectedFilter == 'all',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'all';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.songs} (${results['tracks']!.length})'),
            selected: _selectedFilter == 'tracks',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'tracks';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.albums} (${results['albums']!.length})'),
            selected: _selectedFilter == 'albums',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'albums';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.artists} (${results['artists']!.length})'),
            selected: _selectedFilter == 'artists',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'artists';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.playlists} (${results['playlists']!.length})'),
            selected: _selectedFilter == 'playlists',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'playlists';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(AppState appState, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick suggestions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.quickSuggestions,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSuggestionChip('Rock'),
                      _buildSuggestionChip('Pop'),
                      _buildSuggestionChip('Jazz'),
                      _buildSuggestionChip('Classical'),
                      _buildSuggestionChip('Electronic'),
                      _buildSuggestionChip('Alternative'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recent searches (placeholder)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recentSearches,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.yourRecentSearches,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Browse categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.browseYourLibrary,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.albums,
                          l10n.countAlbums(appState.albums.length),
                          Icons.album,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.artists,
                          l10n.countArtists(appState.artists.length),
                          Icons.person,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.playlists,
                          l10n.countPlaylists(appState.playlists.length),
                          Icons.playlist_play,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      onPressed: () {
        _searchController.text = suggestion;
        setState(() {
          _searchQuery = suggestion;
        });
      },
    );
  }

  Widget _buildBrowseCard(String title, String subtitle, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: () {
          _handleBrowseCardTap(title);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  Widget _buildNoResults(AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noResultsFor(_searchQuery),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryDifferentSearch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              _searchFocusNode.requestFocus();
            },
            child: Text(l10n.clearSearch),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppState appState, Map<String, List<dynamic>> results, AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top result
          if (_selectedFilter == 'all' && _getTotalResults(results) > 0)
            _buildTopResult(appState, results, l10n),
          
          // Filtered results
          if (_selectedFilter == 'all' || _selectedFilter == 'tracks')
            _buildSectionResults(appState, l10n.songs, results['tracks']!, 'track'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'albums')
            _buildSectionResults(appState, l10n.albums, results['albums']!, 'album'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'artists')
            _buildSectionResults(appState, l10n.artists, results['artists']!, 'artist'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'playlists')
            _buildSectionResults(appState, 'Playlists', results['playlists']!, 'playlist'),
        ],
      ),
    );
  }

  Widget _buildTopResult(AppState appState, Map<String, List<dynamic>> results) {
    // Find the first non-empty result as the top result
    dynamic topResult;
    String topResultType = '';
    
    for (final entry in results.entries) {
      if (entry.value.isNotEmpty) {
        topResult = entry.value.first;
        topResultType = entry.key.substring(0, entry.key.length - 1); // Remove 's' from plural
        break;
      }
    }
    
    if (topResult == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Result',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildResultItem(appState, topResult, topResultType, isTopResult: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionResults(AppState appState, String title, List<dynamic> items, String type) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final displayItems = _selectedFilter == 'all' ? items.take(5).toList() : items;
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter == 'all' && items.length > 5)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = '${type}s'; // Convert to plural
                      });
                    },
                    child: Text('View All (${items.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...displayItems.map((item) => _buildResultItem(appState, item, type)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(AppState appState, dynamic item, String type, {bool isTopResult = false}) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: _buildResultLeading(appState, item, type),
      title: Text(
        _getItemTitle(item, type),
        style: isTopResult 
            ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Text(_getItemSubtitle(item, type)),
      trailing: _buildResultTrailing(appState, item, type),
      onTap: () {
        _handleItemTap(appState, item, type);
      },
      contentPadding: isTopResult 
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  Widget _buildResultLeading(AppState appState, dynamic item, String type) {
    final theme = Theme.of(context);
    final size = 48.0;
    
    switch (type) {
      case 'track':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'album':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.album, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.album, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'artist':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: item.imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'playlist':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.playlist_play, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.playlist_play, color: theme.colorScheme.onSurfaceVariant),
        );
      default:
        return Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant);
    }
  }

  Widget _buildResultTrailing(AppState appState, dynamic item, String type) {
    switch (type) {
      case 'track':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.duration != null)
              Text(
                _formatDuration(item.duration!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              onPressed: () {
                _handlePlayTrack(appState, item);
              },
              icon: const Icon(Icons.play_arrow),
              iconSize: 20,
            ),
          ],
        );
      default:
        return IconButton(
          onPressed: () {
            _handleItemTap(appState, item, type);
          },
          icon: const Icon(Icons.play_arrow),
          iconSize: 20,
        );
    }
  }

  void _handleItemTap(AppState appState, dynamic item, String type) {
    switch (type) {
      case 'track':
        _handlePlayTrack(appState, item);
        break;
      case 'album':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.album(album: item),
          ),
        );
        break;
      case 'artist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsPage(artist: item),
          ),
        );
        break;
      case 'playlist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.playlist(playlist: item),
          ),
        );
        break;
    }
  }

  void _handlePlayTrack(AppState appState, dynamic track) {
    // Play the selected track
    appState.playTrack(track);
  }

  void _handleBrowseCardTap(String title) {
    // Set filter and show browse mode
    setState(() {
      switch (title) {
        case 'Albums':
          _selectedFilter = 'albums';
          break;
        case 'Artists':
          _selectedFilter = 'artists';
          break;
        case 'Playlists':
          _selectedFilter = 'playlists';
          break;
      }
      _searchQuery = '*'; // Use asterisk to indicate browse all mode
      _searchController.text = '';
    });
  }

  String _getItemTitle(dynamic item, String type) {
    return item.name;
  }

  String _getItemSubtitle(dynamic item, String type) {
    switch (type) {
      case 'track':
        final parts = <String>[];
        if (item.artistName != null) parts.add(item.artistName!);
        if (item.albumName != null) parts.add(item.albumName!);
        return parts.join(' • ');
      case 'album':
        return item.artistName ?? 'Unknown Artist';
      case 'artist':
        return 'Artist';
      case 'playlist':
        return '${item.trackCount} songs';
      default:
        return '';
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
