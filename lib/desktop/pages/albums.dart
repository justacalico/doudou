import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import 'details/album_details.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, artist, year, dateAdded
  bool _isAscending = true;
  String _filterBy = 'all'; // all, favorites, recent
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.jellyfinService.getImageUrl(imageId);
  }

  List<dynamic> _getFilteredAndSortedAlbums(AppState appState) {
    var albums = List.from(appState.albums);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      albums = albums.where((album) {
        return album.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (album.artistName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }
    
    // Filter by category
    switch (_filterBy) {
      case 'favorites':
        albums = albums.where((album) => album.isFavorite).toList();
        break;
      case 'recent':
        albums = albums.where((album) => album.dateCreated != null).toList();
        albums.sort((a, b) => (b.dateCreated ?? DateTime(1970)).compareTo(a.dateCreated ?? DateTime(1970)));
        albums = albums.take(50).toList();
        break;
    }
    
    // Sort albums
    albums.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'artist':
          comparison = (a.artistName ?? '').toLowerCase().compareTo((b.artistName ?? '').toLowerCase());
          break;
        case 'year':
          comparison = (a.year ?? 0).compareTo(b.year ?? 0);
          break;
        case 'dateAdded':
          comparison = (a.dateCreated ?? DateTime(1970)).compareTo(b.dateCreated ?? DateTime(1970));
          break;
      }
      return _isAscending ? comparison : -comparison;
    });
    
    return albums;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredAlbums = _getFilteredAndSortedAlbums(appState);
        
        return PageTemplate(
          title: 'Albums',
          actions: [
            // Search field
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search albums...',
                  prefixIcon: const Icon(Icons.search),
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
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            
            // View toggle buttons
            ToggleButtons(
              isSelected: [true, false], // Grid view selected by default
              onPressed: (index) {
                // Toggle between grid and list view
              },
              borderRadius: BorderRadius.circular(8),
              children: const [
                Tooltip(
                  message: 'Grid View',
                  child: Icon(Icons.grid_view),
                ),
                Tooltip(
                  message: 'List View',
                  child: Icon(Icons.list),
                ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Refresh button
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Albums',
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredAlbums.length),
              
              const SizedBox(height: 16),
              
              // Content area
              Expanded(
                child: appState.isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading albums...'),
                          ],
                        ),
                      )
                    : filteredAlbums.isEmpty
                        ? _buildEmptyState()
                        : _buildAlbumsGrid(appState, filteredAlbums),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSortBar(AppState appState, int filteredCount) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Results count
            Text(
              '$filteredCount albums',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Filter dropdown
            Text('Filter:', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _filterBy,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filterBy = value;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Albums')),
                DropdownMenuItem(value: 'favorites', child: Text('Favorites')),
                DropdownMenuItem(value: 'recent', child: Text('Recently Added')),
              ],
            ),
            
            const SizedBox(width: 24),
            
            // Sort dropdown
            Text('Sort by:', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _sortBy,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortBy = value;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Album Name')),
                DropdownMenuItem(value: 'artist', child: Text('Artist')),
                DropdownMenuItem(value: 'year', child: Text('Year')),
                DropdownMenuItem(value: 'dateAdded', child: Text('Date Added')),
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Sort direction toggle
            IconButton(
              onPressed: () {
                setState(() {
                  _isAscending = !_isAscending;
                });
              },
              icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _isAscending ? 'Ascending' : 'Descending',
            ),
            
            const Spacer(),
            
            // Quick action buttons
            TextButton.icon(
              onPressed: () {
                // Play all albums
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
            ),
            
            const SizedBox(width: 8),
            
            TextButton.icon(
              onPressed: () {
                // Shuffle all albums
              },
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.album_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No albums found for "$_searchQuery"'
                : _filterBy == 'favorites'
                    ? 'No favorite albums yet'
                    : 'No albums found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : _filterBy == 'favorites'
                    ? 'Add albums to favorites by clicking the heart icon'
                    : 'Your music library appears to be empty',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlbumsGrid(AppState appState, List<dynamic> albums) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6, // 6 albums per row
        childAspectRatio: 0.75, // Slightly taller than square
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _buildAlbumCard(appState, album);
      },
    );
  }

  Widget _buildAlbumCard(AppState appState, dynamic album) {
    final theme = Theme.of(context);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navigate to album details
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                    ),
                    child: album.imageUrl != null
                        ? Image.network(
                            _getImageUrl(appState, album.imageUrl)!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildAlbumPlaceholder(theme);
                            },
                          )
                        : _buildAlbumPlaceholder(theme),
                  ),
                  
                  // Overlay with play button (appears on hover)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Play album
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: Icon(
                          album.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: album.isFavorite ? Colors.red : Colors.white,
                        ),
                        onPressed: () {
                          // Toggle favorite
                        },
                        iconSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Album info
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            album.artistName ?? 'Unknown Artist',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (album.year != null) ...[
                          Text(
                            ' • ${album.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.album,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}
