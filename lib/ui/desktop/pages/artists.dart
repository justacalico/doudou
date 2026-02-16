import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../../../providers/app_state.dart';
import '../services/navigation_service.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, albumCount
  bool _isAscending = true;
  String _viewMode = 'grid'; // grid, list

  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _genericArtistImageCache = {};
  final Map<String, Future<bool>> _genericArtistImageDetectionFutures = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _genericArtistImageCache.clear();
    _genericArtistImageDetectionFutures.clear();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.artists.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  bool _shouldUseArtistPlaceholderByMetadata(dynamic artist) {
    final artistName = (artist.name as String? ?? '').toLowerCase().trim();
    final normalizedName = artistName
        .replaceAll(RegExp(r'[\[\]\(\)\-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const placeholderNames = {
      'unknown',
      'unknown artist',
      'various',
      'various artists',
    };

    return artist.imageUrl == null || placeholderNames.contains(normalizedName);
  }

  Future<ui.Image> _resolveUiImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final imageStream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo imageInfo, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(imageInfo.image);
        }
        imageStream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        imageStream.removeListener(listener);
      },
    );

    imageStream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<bool> _isLikelyGenericArtistImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return false;

    final bytes = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final stepX = math.max(1, width ~/ 24);
    final stepY = math.max(1, height ~/ 24);

    int sampledPixels = 0;
    int grayLikePixels = 0;
    int alphaPixels = 0;
    double meanLuminance = 0;
    double m2 = 0;
    final Set<int> colorBuckets = <int>{};

    for (int y = 0; y < height; y += stepY) {
      for (int x = 0; x < width; x += stepX) {
        final index = (y * width + x) * 4;
        final r = bytes[index];
        final g = bytes[index + 1];
        final b = bytes[index + 2];
        final a = bytes[index + 3];

        if (a < 16) {
          continue;
        }

        alphaPixels++;
        sampledPixels++;

        final maxChannel = math.max(r, math.max(g, b));
        final minChannel = math.min(r, math.min(g, b));
        if (maxChannel - minChannel < 18) {
          grayLikePixels++;
        }

        final bucket = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
        colorBuckets.add(bucket);

        final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        final delta = luminance - meanLuminance;
        meanLuminance += delta / sampledPixels;
        m2 += delta * (luminance - meanLuminance);
      }
    }

    if (sampledPixels == 0 || alphaPixels == 0) {
      return false;
    }

    final grayRatio = grayLikePixels / sampledPixels;
    final luminanceVariance = sampledPixels > 1 ? m2 / (sampledPixels - 1) : 0;

    // Generic fallback art from media servers is typically near-monochrome with low color diversity.
    return grayRatio > 0.9 &&
        colorBuckets.length <= 42 &&
        luminanceVariance < 2600;
  }

  Future<bool> _detectAndCacheGenericArtistImage(String imageUrl) {
    final cached = _genericArtistImageCache[imageUrl];
    if (cached != null) {
      return Future.value(cached);
    }

    return _genericArtistImageDetectionFutures.putIfAbsent(imageUrl, () async {
      try {
        final image = await _resolveUiImage(NetworkImage(imageUrl));
        final isGeneric = await _isLikelyGenericArtistImage(image);
        _genericArtistImageCache[imageUrl] = isGeneric;
        return isGeneric;
      } catch (_) {
        _genericArtistImageCache[imageUrl] = false;
        return false;
      } finally {
        _genericArtistImageDetectionFutures.remove(imageUrl);
      }
    });
  }

  Widget _buildArtistAvatar(
    ThemeData theme,
    AppState appState,
    dynamic artist, {
    required double width,
    required double height,
  }) {
    if (_shouldUseArtistPlaceholderByMetadata(artist)) {
      return _buildArtistPlaceholder(theme);
    }

    final imageUrl = _getImageUrl(appState, artist.imageUrl);
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildArtistPlaceholder(theme);
    }

    final cachedDecision = _genericArtistImageCache[imageUrl];
    if (cachedDecision == true) {
      return _buildArtistPlaceholder(theme);
    }

    final image = ClipOval(
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildArtistPlaceholder(theme);
        },
      ),
    );

    if (cachedDecision == false) {
      return image;
    }

    return FutureBuilder<bool>(
      future: _detectAndCacheGenericArtistImage(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return _buildArtistPlaceholder(theme);
        }
        return image;
      },
    );
  }

  List<dynamic> _getFilteredAndSortedArtists(AppState appState) {
    var artists = List.from(appState.artists);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      artists = artists.where((artist) {
        return artist.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort artists
    artists.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'albumCount':
          // Get album count for each artist by counting albums
          final aAlbumCount = appState.albums
              .where((album) => album.artistName == a.name)
              .length;
          final bAlbumCount = appState.albums
              .where((album) => album.artistName == b.name)
              .length;
          comparison = aAlbumCount.compareTo(bAlbumCount);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });

    return artists;
  }

  int _getArtistAlbumCount(AppState appState, String artistName) {
    return appState.albums
        .where((album) => album.artistName == artistName)
        .length;
  }

  int _getArtistTrackCount(AppState appState, String artistName) {
    return appState.tracks
        .where((track) => track.artistName == artistName)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredArtists = _getFilteredAndSortedArtists(appState);

        return PageTemplate(
          title: l10n.artists,
          actions: [
            // Search field
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchArtists,
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
              isSelected: [_viewMode == 'grid', _viewMode == 'list'],
              onPressed: (index) {
                setState(() {
                  _viewMode = index == 0 ? 'grid' : 'list';
                });
              },
              borderRadius: BorderRadius.circular(8),
              children: [
                Tooltip(
                  message: l10n.gridView,
                  child: const Icon(Icons.grid_view),
                ),
                Tooltip(message: l10n.listView, child: const Icon(Icons.list)),
              ],
            ),

            const SizedBox(width: 16),

            // Refresh button
            IconButton(
              onPressed: () => appState.loadLibraryData(),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refreshArtists,
            ),
          ],
          child: Column(
            children: [
              // Filter and sort controls
              _buildFilterSortBar(appState, filteredArtists.length, l10n),

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
                            Text(l10n.loadingArtists),
                          ],
                        ),
                      )
                    : filteredArtists.isEmpty
                    ? _buildEmptyState(l10n)
                    : _viewMode == 'grid'
                    ? _buildArtistsGrid(appState, filteredArtists, l10n)
                    : _buildArtistsList(appState, filteredArtists, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSortBar(
    AppState appState,
    int filteredCount,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Results count
            Text(
              l10n.artistsCount(filteredCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(width: 24),

            // Sort dropdown
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
                DropdownMenuItem(value: 'name', child: Text(l10n.name)),
                DropdownMenuItem(
                  value: 'albumCount',
                  child: Text(l10n.albumCountSort),
                ),
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
              icon: Icon(
                _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              tooltip: _isAscending ? l10n.ascending : l10n.descending,
            ),

            const Spacer(),

            // Quick action buttons
            TextButton.icon(
              onPressed: filteredCount > 0
                  ? () {
                      // Play all artists
                    }
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.playAll),
            ),

            const SizedBox(width: 8),

            TextButton.icon(
              onPressed: filteredCount > 0
                  ? () {
                      // Shuffle all artists
                    }
                  : null,
              icon: const Icon(Icons.shuffle),
              label: Text(l10n.shuffleAll),
            ),
          ],
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
            Icons.person_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? l10n.noResultsFor(_searchQuery)
                : l10n.noArtistsFound,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? l10n.tryDifferentSearch
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

  Widget _buildArtistsGrid(
    AppState appState,
    List<dynamic> artists,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive column count based on available width
        // Minimum card width of 150px, maximum of 200px
        final minCardWidth = 150.0;
        final crossAxisCount = (constraints.maxWidth / minCardWidth)
            .floor()
            .clamp(2, 8);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio:
                0.75, // Better ratio for artist cards with circular images
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return _buildArtistCard(appState, artist, l10n);
          },
        );
      },
    );
  }

  Widget _buildArtistsList(
    AppState appState,
    List<dynamic> artists,
    AppLocalizations l10n,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return _buildArtistListTile(appState, artist, l10n);
      },
    );
  }

  Widget _buildArtistCard(
    AppState appState,
    dynamic artist,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final albumCount = _getArtistAlbumCount(appState, artist.name);
    final trackCount = _getArtistTrackCount(appState, artist.name);
    final navigationService = NavigationService();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          navigationService.navigateToArtist(artist);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artist image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: _buildArtistAvatar(
                  theme,
                  appState,
                  artist,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // Artist info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.artistAlbumsAndSongs(albumCount, trackCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistListTile(
    AppState appState,
    dynamic artist,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final albumCount = _getArtistAlbumCount(appState, artist.name);
    final trackCount = _getArtistTrackCount(appState, artist.name);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: _buildArtistAvatar(
            theme,
            appState,
            artist,
            width: 56,
            height: 56,
          ),
        ),
        title: Text(
          artist.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.artistAlbumsAndSongs(albumCount, trackCount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                // Play artist
              },
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.playAll,
            ),
            IconButton(
              onPressed: () {
                // Shuffle artist
              },
              icon: const Icon(Icons.shuffle),
              tooltip: l10n.shuffle,
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleArtistAction(value, artist),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play',
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: Text(l10n.playAll),
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
                  value: 'albums',
                  child: ListTile(
                    leading: const Icon(Icons.album),
                    title: Text(l10n.viewAlbums),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Navigate to artist details
        },
      ),
    );
  }

  Widget _buildArtistPlaceholder(ThemeData theme) {
    final iconColor = theme.brightness == Brightness.dark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant.withOpacity(0.7);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.account_circle_outlined, size: 36, color: iconColor),
    );
  }

  void _handleArtistAction(String action, dynamic artist) {
    switch (action) {
      case 'play':
        // Play all songs by this artist
        break;
      case 'shuffle':
        // Shuffle all songs by this artist
        break;
      case 'albums':
        // Navigate to albums by this artist
        break;
    }
  }
}
