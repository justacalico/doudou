import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import 'details/media_details.dart';

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
    return appState.getImageUrl(imageId);
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
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredAlbums = _getFilteredAndSortedAlbums(appState);
        
        return PageTemplate(
          title: l10n.albums,
          actions: [
            // Search field - responsive width
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive search field width
                double searchWidth;
                if (constraints.maxWidth < 600) {
                  searchWidth = constraints.maxWidth * 0.4; // 40% of available width
                } else if (constraints.maxWidth < 900) {
                  searchWidth = 250;
                } else {
                  searchWidth = 300;
                }
                
                return SizedBox(
                  width: searchWidth.clamp(150, 300), // Min 150px, Max 300px
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchAlbums,
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
                );
              },
            ),
            // Responsive spacing and controls
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                
                return Row(
                  children: [
                    SizedBox(width: isNarrow ? 8 : 16),
                    
                    // View toggle buttons - hide on very small screens
                    if (!isNarrow) ...[
                      ToggleButtons(
                        isSelected: [true, false], // Grid view selected by default
                        onPressed: (index) {
                          // Toggle between grid and list view
                        },
                        borderRadius: BorderRadius.circular(8),
                        children: [
                          Tooltip(
                            message: l10n.gridView,
                            child: const Icon(Icons.grid_view),
                          ),
                          Tooltip(
                            message: l10n.listView,
                            child: const Icon(Icons.list),
                          ),
                        ],
                      ),
                      SizedBox(width: isNarrow ? 8 : 16),
                    ],
                    
                    // Refresh button
                    IconButton(
                      onPressed: () => appState.loadLibraryData(),
                      icon: const Icon(Icons.refresh),
                      tooltip: l10n.refreshAlbums,
                    ),
                  ],
                );
              },
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredAlbums.length, l10n),
              
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
                            Text(l10n.loadingAlbums),
                          ],
                        ),
                      )
                    : filteredAlbums.isEmpty
                        ? _buildEmptyState(l10n)
                        : _buildAlbumsGrid(appState, filteredAlbums, l10n),
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
            // Responsive layout based on available width
            final isNarrow = constraints.maxWidth < 800;
            
            if (isNarrow) {
              // Compact layout for small screens
              return Column(
                children: [
                  // First row: Results count and quick actions
                  Row(
                    children: [
                      Text(
                        l10n.albumsCount(filteredCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _buildQuickActions(appState, l10n),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row: Filter and sort controls
                  Row(
                    children: [
                      _buildFilterControls(theme, l10n),
                      const Spacer(),
                      _buildSortControls(theme, l10n),
                    ],
                  ),
                ],
              );
            } else {
              // Full layout for larger screens
              return Row(
                children: [
                  // Results count
                  Text(
                    l10n.albumsCount(filteredCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildFilterControls(theme, l10n),
                  const SizedBox(width: 24),
                  _buildSortControls(theme, l10n),
                  const Spacer(),
                  _buildQuickActions(appState, l10n),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterControls(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            DropdownMenuItem(value: 'all', child: Text(l10n.allAlbums)),
            DropdownMenuItem(value: 'favorites', child: Text(l10n.favorites)),
            DropdownMenuItem(value: 'recent', child: Text(l10n.recentlyAdded)),
          ],
        ),
      ],
    );
  }

  Widget _buildSortControls(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.sortBy, style: theme.textTheme.bodyMedium),
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
            DropdownMenuItem(value: 'name', child: Text(l10n.albumName)),
            DropdownMenuItem(value: 'artist', child: Text(l10n.artist)),
            DropdownMenuItem(value: 'year', child: Text(l10n.year)),
            DropdownMenuItem(value: 'dateAdded', child: Text(l10n.dateAdded)),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            setState(() {
              _isAscending = !_isAscending;
            });
          },
          icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
          tooltip: _isAscending ? l10n.ascending : l10n.descending,
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppState appState, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () async {
            final filteredAlbums = _getFilteredAndSortedAlbums(appState);
            if (filteredAlbums.isNotEmpty) {
              List<Track> allTracks = [];
              for (var album in filteredAlbums) {
                final tracks = await appState.getAlbumTracks(album.id);
                allTracks.addAll(tracks);
              }
              if (allTracks.isNotEmpty) {
                await appState.playPlaylist(allTracks, 0);
              }
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.playAll),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () async {
            final filteredAlbums = _getFilteredAndSortedAlbums(appState);
            if (filteredAlbums.isNotEmpty) {
              List<Track> allTracks = [];
              for (var album in filteredAlbums) {
                final tracks = await appState.getAlbumTracks(album.id);
                allTracks.addAll(tracks);
              }
              if (allTracks.isNotEmpty) {
                allTracks.shuffle();
                await appState.playPlaylist(allTracks, 0);
              }
            }
          },
          icon: const Icon(Icons.shuffle),
          label: Text(l10n.shuffleAll),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
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
                ? l10n.noResultsFor(_searchQuery)
                : _filterBy == 'favorites'
                    ? l10n.noFavoriteAlbums
                    : l10n.noAlbumsFound,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? l10n.tryDifferentSearch
                : _filterBy == 'favorites'
                    ? l10n.addAlbumsToFavorites
                    : l10n.musicLibraryEmpty,
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
              child: Text(l10n.clearSearch),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlbumsGrid(AppState appState, List<dynamic> albums, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive grid columns based on screen width
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth < 600) {
          // Very small screens: 2 columns
          crossAxisCount = 2;
          childAspectRatio = 0.85;
        } else if (constraints.maxWidth < 900) {
          // Small screens: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 0.8;
        } else if (constraints.maxWidth < 1200) {
          // Medium screens: 4 columns
          crossAxisCount = 4;
          childAspectRatio = 0.75;
        } else if (constraints.maxWidth < 1500) {
          // Large screens: 5 columns
          crossAxisCount = 5;
          childAspectRatio = 0.75;
        } else {
          // Extra large screens: 6 columns
          crossAxisCount = 6;
          childAspectRatio = 0.75;
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _buildAlbumCard(appState, album, l10n);
          },
        );
      },
    );
  }

  Widget _buildAlbumCard(AppState appState, dynamic album) {
    final theme = Theme.of(context);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaDetailsPage.album(album: album),
            ),
          );
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
                        onTap: () async {
                          final tracks = await appState.getAlbumTracks(album.id);
                          if (tracks.isNotEmpty) {
                            await appState.playPlaylist(tracks, 0);
                          }
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
                  
                  // Top right controls
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // More options button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                            color: theme.colorScheme.surface,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'addToPlaylist',
                                child: ListTile(
                                  leading: Icon(Icons.playlist_add),
                                  title: Text('Add to playlist'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'play',
                                child: ListTile(
                                  leading: Icon(Icons.play_arrow),
                                  title: Text('Play album'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'addToQueue',
                                child: ListTile(
                                  leading: Icon(Icons.queue_music),
                                  title: Text('Add to queue'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            onSelected: (value) => _handleAlbumAction(value, appState, album),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Favorite button
                        Container(
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Album info - responsive padding and text
            Expanded(
              flex: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Adjust padding and text size based on card width
                  final isSmall = constraints.maxWidth < 160;
                  final padding = isSmall ? 8.0 : 12.0;
                  
                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          album.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmall ? 12 : null,
                          ),
                          maxLines: isSmall ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmall ? 2 : 4),
                        if (isSmall) ...[
                          // Simplified layout for very small cards
                          Text(
                            album.artistName ?? 'Unknown Artist',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          // Full layout for larger cards
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAlbumAction(String action, AppState appState, dynamic album) async {
    switch (action) {
      case 'addToPlaylist':
        // Get all tracks from the album
        final tracks = await appState.getAlbumTracks(album.id);
        if (tracks.isNotEmpty) {
          _showAddAlbumToPlaylistDialog(appState, album, tracks);
        }
        break;
      case 'play':
        final tracks = await appState.getAlbumTracks(album.id);
        if (tracks.isNotEmpty) {
          await appState.playPlaylist(tracks, 0);
        }
        break;
      case 'addToQueue':
        final tracks = await appState.getAlbumTracks(album.id);
        for (final track in tracks) {
          appState.addToQueue(track);
        }
        break;
    }
  }

  void _showAddAlbumToPlaylistDialog(AppState appState, dynamic album, List<Track> tracks) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.playlist_add),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Add Album to Playlist'),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.album,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${album.artistName} • ${tracks.length} tracks',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                
                const SizedBox(height: 16),
                
                // Playlist selection
                Text(
                  'Select Playlist:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                
                if (appState.playlists.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.playlist_remove,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No playlists available',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: appState.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = appState.playlists[index];
                        
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.playlist_play),
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.trackCount} tracks'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _addAlbumToPlaylist(appState, playlist.id, tracks, album.name);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addAlbumToPlaylist(AppState appState, String playlistId, List<Track> tracks, String albumName) async {
    try {
      int successCount = 0;
      for (final track in tracks) {
        final success = await appState.addToPlaylist(playlistId, track.id);
        if (success) successCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount == tracks.length 
                ? 'Added "$albumName" ($successCount tracks) to playlist'
                : 'Added $successCount of ${tracks.length} tracks from "$albumName" to playlist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding album to playlist: $e')),
        );
      }
    }
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
