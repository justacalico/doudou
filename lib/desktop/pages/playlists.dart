import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import '../services/navigation_service.dart';

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
      if (kDebugMode) {
        print('=== PLAYLISTS DEBUG ===');
      }
      if (kDebugMode) {
        print('Current playlists count: ${appState.playlists.length}');
      }
      if (kDebugMode) {
        print('Is logged in: ${appState.isLoggedIn}');
      }
      if (kDebugMode) {
        print('Current server type: ${appState.mediaServiceManager.currentServerType}');
      }
      if (appState.playlists.isEmpty) {
        if (kDebugMode) {
          print('No playlists found, calling loadLibraryData()');
        }
        appState.loadLibraryData();
      } else {
        if (kDebugMode) {
          print('Playlists found:');
        }
        for (final playlist in appState.playlists.take(5)) {
          if (kDebugMode) {
            print('  - ${playlist.name} (${playlist.trackCount} tracks)');
          }
        }
      }
      if (kDebugMode) {
        print('=== END PLAYLISTS DEBUG ===');
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
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredPlaylists = _getFilteredAndSortedPlaylists(appState);
        
        return PageTemplate(
          title: l10n.navPlaylists,
          actions: [
            // Create new playlist button
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context, l10n),
              icon: const Icon(Icons.add),
              label: Text(l10n.createPlaylist),
            ),
            
            const SizedBox(width: 16),
            
            // Search field
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchPlaylists,
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
              tooltip: l10n.tooltipRefresh,
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredPlaylists.length, l10n),
              
              const SizedBox(height: 16),
              
              // Content area
              Expanded(
                child: appState.isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(l10n.loadingPlaylists),
                          ],
                        ),
                      )
                    : filteredPlaylists.isEmpty
                        ? _buildEmptyState(l10n)
                        : _buildPlaylistsGrid(appState, filteredPlaylists, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSortBar(AppState appState, int filteredCount, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            
            if (isNarrow) {
              // Compact layout for narrow screens
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First row: count and play buttons
                  Row(
                    children: [
                      Text(
                        l10n.countPlaylists(filteredCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: filteredCount > 0 ? () {} : null,
                        icon: const Icon(Icons.play_arrow),
                        tooltip: l10n.playAll,
                      ),
                      IconButton(
                        onPressed: filteredCount > 0 ? () {} : null,
                        icon: const Icon(Icons.shuffle),
                        tooltip: l10n.shuffleAll,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second row: filter and sort
                  Row(
                    children: [
                      Text(l10n.filter, style: theme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      DropdownButton<String>(
                        value: _filterBy,
                        isDense: true,
                        onChanged: (value) {
                          if (value != null) setState(() => _filterBy = value);
                        },
                        items: [
                          DropdownMenuItem(value: 'all', child: Text(l10n.allPlaylists)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Text('${l10n.sortBy}:', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      DropdownButton<String>(
                        value: _sortBy,
                        isDense: true,
                        onChanged: (value) {
                          if (value != null) setState(() => _sortBy = value);
                        },
                        items: [
                          DropdownMenuItem(value: 'name', child: Text(l10n.name)),
                          DropdownMenuItem(value: 'trackCount', child: Text(l10n.trackCount)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isAscending = !_isAscending),
                        icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                        tooltip: _isAscending ? l10n.ascending : l10n.descending,
                      ),
                    ],
                  ),
                ],
              );
            }
            
            // Normal layout for wider screens - use Flexible to prevent overflow
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Results count
                  Text(
                    l10n.countPlaylists(filteredCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Filter dropdown
                  Text(l10n.filter, style: theme.textTheme.bodyMedium),
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
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(l10n.allPlaylists)),
                    ],
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Sort dropdown
                  Text('${l10n.sortBy}:', style: theme.textTheme.bodyMedium),
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
                    items: [
                      DropdownMenuItem(value: 'name', child: Text(l10n.name)),
                      DropdownMenuItem(value: 'trackCount', child: Text(l10n.trackCount)),
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
                    tooltip: _isAscending ? l10n.ascending : l10n.descending,
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Quick action buttons - icons only to save space
                  IconButton(
                    onPressed: filteredCount > 0 ? () {} : null,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: l10n.playAll,
                  ),
                  
                  IconButton(
                    onPressed: filteredCount > 0 ? () {} : null,
                    icon: const Icon(Icons.shuffle),
                    tooltip: l10n.shuffleAll,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
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
                ? l10n.noResultsFor(_searchQuery)
                : l10n.noPlaylistsFound,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? l10n.tryDifferentSearch
                : l10n.createFirstPlaylist,
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
              child: Text(l10n.clearSearch),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context, l10n),
              icon: const Icon(Icons.add),
              label: Text(l10n.createPlaylist),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsGrid(AppState appState, List<dynamic> playlists, AppLocalizations l10n) {
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
        return _buildPlaylistCard(appState, playlist, l10n);
      },
    );
  }

  Widget _buildPlaylistCard(AppState appState, dynamic playlist, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final navigationService = NavigationService();
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          navigationService.navigateToPlaylist(playlist);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist artwork
            Expanded(
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
                            SnackBar(
                              content: Text(l10n.favoritesNotImplemented),
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
                        onSelected: (value) => _handlePlaylistAction(value, playlist, l10n),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'play',
                            child: ListTile(
                              leading: const Icon(Icons.play_arrow),
                              title: Text(l10n.play),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'shuffle',
                            child: ListTile(
                              leading: const Icon(Icons.shuffle),
                              title: Text(l10n.shuffle),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: const Icon(Icons.edit),
                              title: Text(l10n.editPlaylist),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: Text(l10n.deletePlaylist, style: const TextStyle(color: Colors.red)),
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.countSongs(playlist.trackCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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

  void _handlePlaylistAction(String action, dynamic playlist, AppLocalizations l10n) {
    switch (action) {
      case 'play':
        // Play playlist
        break;
      case 'shuffle':
        // Shuffle playlist
        break;
      case 'edit':
        _showEditPlaylistDialog(context, playlist, l10n);
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, playlist, l10n);
        break;
    }
  }

  void _showCreatePlaylistDialog(BuildContext context, AppLocalizations l10n) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createPlaylist),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.playlistName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _createPlaylist(nameController.text.trim(), l10n);
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(String name, AppLocalizations l10n) async {
    final appState = context.read<AppState>();
    
    try {
      final success = await appState.createPlaylist(name);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.playlistCreated(name)),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the playlists list
          appState.loadLibraryData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorCreatingPlaylist(name)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorCreatingPlaylist(name)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditPlaylistDialog(BuildContext context, dynamic playlist, AppLocalizations l10n) {
    final nameController = TextEditingController(text: playlist.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editPlaylist),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.playlistName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && nameController.text.trim() != playlist.name) {
                Navigator.of(context).pop();
                _updatePlaylist(playlist.id, nameController.text.trim(), l10n);
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePlaylist(String playlistId, String newName, AppLocalizations l10n) async {
    final appState = context.read<AppState>();
    
    try {
      final success = await appState.renamePlaylist(playlistId, newName);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.playlistRenamed(newName)),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the playlists list
          appState.loadLibraryData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToRenamePlaylist(newName)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRenamingPlaylist(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeletePlaylistDialog(BuildContext context, dynamic playlist, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePlaylist),
        content: Text(l10n.deletePlaylistConfirm(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePlaylist(playlist.id, playlist.name, l10n);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(String playlistId, String playlistName, AppLocalizations l10n) async {
    final appState = context.read<AppState>();
    
    try {
      final success = await appState.removePlaylist(playlistId);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.playlistDeleted(playlistName)),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh the playlists list
          appState.loadLibraryData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToDeletePlaylist),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingPlaylist(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
