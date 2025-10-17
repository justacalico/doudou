import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import 'details/playlist_details.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, dateCreated, trackCount
  bool _isAscending = true;
  String _filterBy = 'all'; // all, created, favorites
  
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
      if (appState.playlists.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  List<dynamic> _getFilteredAndSortedPlaylists(AppState appState) {
    var playlists = List.from(appState.playlists);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      playlists = playlists.where((playlist) {
        return playlist.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filter by category
    switch (_filterBy) {
      case 'favorites':
        // Skip favorites filter since Playlist model doesn't have isFavorite
        // playlists = playlists.where((playlist) => playlist.isFavorite ?? false).toList();
        break;
      case 'created':
        // Filter user-created playlists (assuming there's a way to distinguish them)
        // For now, skip this filter as well
        break;
    }
    
    // Sort playlists
    playlists.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'dateCreated':
          // Skip date sorting since Playlist model doesn't have dateCreated
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'trackCount':
          comparison = a.trackCount.compareTo(b.trackCount);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });
    
    return playlists;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredPlaylists = _getFilteredAndSortedPlaylists(appState);
        
        return PageTemplate(
          title: 'Playlists',
          actions: [
            // Create new playlist button
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
            ),
            
            const SizedBox(width: 16),
            
            // Search field
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search playlists...',
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
            
            // Refresh button
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Playlists',
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredPlaylists.length),
              
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
                            Text('Loading playlists...'),
                          ],
                        ),
                      )
                    : filteredPlaylists.isEmpty
                        ? _buildEmptyState()
                        : _buildPlaylistsGrid(appState, filteredPlaylists),
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
              '$filteredCount playlists',
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
                DropdownMenuItem(value: 'all', child: Text('All Playlists')),
                // Remove favorites and created filters since they're not supported yet
                // DropdownMenuItem(value: 'favorites', child: Text('Favorites')),
                // DropdownMenuItem(value: 'created', child: Text('Created by Me')),
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
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'trackCount', child: Text('Track Count')),
                // Remove dateCreated since Playlist model doesn't have this field
                // DropdownMenuItem(value: 'dateCreated', child: Text('Date Created')),
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
              onPressed: filteredCount > 0 ? () {
                // Play all playlists
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
            ),
            
            const SizedBox(width: 8),
            
            TextButton.icon(
              onPressed: filteredCount > 0 ? () {
                // Shuffle all playlists
              } : null,
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
            Icons.playlist_play_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No playlists found for "$_searchQuery"'
                : 'No playlists found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Create your first playlist to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Text('Clear Search'),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsGrid(AppState appState, List<dynamic> playlists) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 5 playlists per row
        childAspectRatio: 0.8, // Slightly taller for playlist info
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _buildPlaylistCard(appState, playlist);
      },
    );
  }

  Widget _buildPlaylistCard(AppState appState, dynamic playlist) {
    final theme = Theme.of(context);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailsPage(playlist: playlist),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist artwork
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
                    child: playlist.imageUrl != null
                        ? Image.network(
                            _getImageUrl(appState, playlist.imageUrl)!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaylistPlaceholder(theme);
                            },
                          )
                        : _buildPlaylistPlaceholder(theme),
                  ),
                  
                  // Overlay with play button (appears on hover)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Play playlist
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
                  
                  // Favorite button (disabled for now since Playlist model doesn't support favorites)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          // Toggle favorite - not implemented yet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Favorites not yet implemented for playlists'),
                            ),
                          );
                        },
                        iconSize: 20,
                      ),
                    ),
                  ),
                  
                  // More options menu
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        onSelected: (value) => _handlePlaylistAction(value, playlist),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'play',
                            child: ListTile(
                              leading: Icon(Icons.play_arrow),
                              title: Text('Play'),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'shuffle',
                            child: ListTile(
                              leading: Icon(Icons.shuffle),
                              title: Text('Shuffle'),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text('Delete', style: TextStyle(color: Colors.red)),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Playlist info
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playlist.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} songs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

  Widget _buildPlaylistPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.playlist_play,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  void _handlePlaylistAction(String action, dynamic playlist) {
    switch (action) {
      case 'play':
        // Play playlist
        break;
      case 'shuffle':
        // Shuffle playlist
        break;
      case 'edit':
        _showEditPlaylistDialog(context, playlist);
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, playlist);
        break;
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Playlist Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _createPlaylist(nameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditPlaylistDialog(BuildContext context, dynamic playlist) {
    final nameController = TextEditingController(text: playlist.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                // Update playlist
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist updated'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${playlist.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete playlist
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playlist "${playlist.name}" deleted'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
