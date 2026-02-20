import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/track_list_template.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/l10n/app_localizations.dart';

import 'media_details.dart';

class ArtistDetailsPage extends StatefulWidget {
  final Artist artist;

  const ArtistDetailsPage({super.key, required this.artist});

  @override
  State<ArtistDetailsPage> createState() => _ArtistDetailsPageState();
}

class _ArtistDetailsPageState extends State<ArtistDetailsPage> {
  List<Album> _artistAlbums = [];
  List<Track> _popularTracks = [];
  bool _isLoading = true;
  String _selectedTab = 'albums'; // albums, songs

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  void _loadArtistData() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      // Get albums by this artist
      _artistAlbums = appState.albums
          .where((album) => album.artistName == widget.artist.name)
          .toList();

      // Sort albums by year (newest first)
      _artistAlbums.sort((a, b) {
        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;
        return bYear.compareTo(aYear);
      });

      // Get popular tracks by this artist
      _popularTracks = appState.tracks
          .where((track) => track.artistName == widget.artist.name)
          .take(10)
          .toList();

      if (_artistAlbums.isEmpty) {
        _selectedTab = 'songs';
      } else if (_selectedTab == 'songs' || _selectedTab == 'albums') {
        // Keep current valid selection.
      } else {
        _selectedTab = 'albums';
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);

        return PageTemplate(
          showBackButton: true,
          title: widget.artist.name,
          onBackPressed: () => Navigator.of(context).pop(),
          child: Column(
            children: [
              // Fixed header section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action buttons row
                    _buildActionButtons(theme, l10n),

                    const SizedBox(height: 24),

                    // Artist header
                    _buildArtistHeader(theme, appState, l10n),

                    const SizedBox(height: 24),

                    // Tab selector
                    _buildTabSelector(theme, l10n),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Scrollable content section
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildTabContent(theme, appState, l10n),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 500;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Play all button
                ElevatedButton.icon(
                  onPressed: _popularTracks.isNotEmpty
                      ? () async {
                          await appState.playPlaylist(_popularTracks, 0);
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(isNarrow ? l10n.play : l10n.playAll),
                ),
                // Shuffle button
                OutlinedButton.icon(
                  onPressed: _popularTracks.isNotEmpty
                      ? () async {
                          final shuffledTracks = List<Track>.from(
                            _popularTracks,
                          )..shuffle();
                          await appState.playPlaylist(shuffledTracks, 0);
                        }
                      : null,
                  icon: const Icon(Icons.shuffle),
                  label: Text(l10n.shuffle),
                ),
                // Favorite button
                IconButton(
                  onPressed: () {
                    // Toggle favorite artist
                  },
                  icon: const Icon(Icons.favorite_border),
                  tooltip: l10n.addToFavorites,
                ),
                // More options
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'follow':
                        // Follow/unfollow artist
                        break;
                      case 'share':
                        // Share artist
                        break;
                      case 'radio':
                        // Start artist radio
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'follow',
                      child: ListTile(
                        leading: const Icon(Icons.person_add),
                        title: Text(l10n.followArtist),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'radio',
                      child: ListTile(
                        leading: const Icon(Icons.radio),
                        title: Text(l10n.startRadio),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: const Icon(Icons.share),
                        title: Text(l10n.share),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildArtistHeader(
    ThemeData theme,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            if (isNarrow) {
              // Vertical layout for narrow screens
              return Column(
                children: [
                  // Artist image
                  _buildArtistImage(
                    theme,
                    appState,
                    constraints.maxWidth < 400 ? 120.0 : 150.0,
                  ),
                  const SizedBox(height: 20),
                  // Artist info
                  _buildArtistInfo(theme, isNarrow, l10n),
                ],
              );
            } else {
              // Horizontal layout for wider screens
              return Row(
                children: [
                  // Artist image
                  _buildArtistImage(
                    theme,
                    appState,
                    constraints.maxWidth < 800 ? 150.0 : 200.0,
                  ),
                  const SizedBox(width: 24),
                  // Artist info
                  Expanded(child: _buildArtistInfo(theme, isNarrow, l10n)),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildArtistImage(ThemeData theme, AppState appState, double size) {
    final iconSize = size * 0.4;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: widget.artist.imageUrl != null
          ? ClipOval(
              child: Image.network(
                _getImageUrl(appState, widget.artist.imageUrl)!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    size: iconSize,
                    color: theme.colorScheme.onSurfaceVariant,
                  );
                },
              ),
            )
          : Icon(
              Icons.person,
              size: iconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }

  Widget _buildArtistInfo(
    ThemeData theme,
    bool isNarrow,
    AppLocalizations l10n,
  ) {
    final hasAlbums = _artistAlbums.isNotEmpty;

    return Column(
      crossAxisAlignment: isNarrow
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          l10n.artist,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.artist.name,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isNarrow ? 24 : null,
          ),
          textAlign: isNarrow ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 16),
        isNarrow
            ? Column(
                children: [
                  if (hasAlbums) ...[
                    Text(
                      l10n.countAlbums(_artistAlbums.length),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    l10n.countSongs(_getTotalTracks()),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  if (hasAlbums) ...[
                    Text(
                      l10n.countAlbums(_artistAlbums.length),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    l10n.countSongs(_getTotalTracks()),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildTabSelector(ThemeData theme, AppLocalizations l10n) {
    final hasAlbums = _artistAlbums.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (hasAlbums) ...[
              _buildTabButton('albums', l10n.albums, theme),
              const SizedBox(width: 8),
            ],
            _buildTabButton('songs', l10n.popularSongs, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabId, String title, ThemeData theme) {
    final isSelected = _selectedTab == tabId;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    ThemeData theme,
    AppState appState,
    AppLocalizations l10n,
  ) {
    if (_artistAlbums.isEmpty) {
      return _buildSongsTab(theme, appState, l10n);
    }

    switch (_selectedTab) {
      case 'albums':
        return _buildAlbumsTab(theme, appState, l10n);
      case 'songs':
        return _buildSongsTab(theme, appState, l10n);
      default:
        return _buildSongsTab(theme, appState, l10n);
    }
  }

  Widget _buildAlbumsTab(
    ThemeData theme,
    AppState appState,
    AppLocalizations l10n,
  ) {
    if (_artistAlbums.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noAlbumsFoundForArtist,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.artistHasNoAlbumsYet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive grid columns
            int crossAxisCount;
            double childAspectRatio;

            if (constraints.maxWidth < 400) {
              crossAxisCount = 1;
              childAspectRatio = 1.2;
            } else if (constraints.maxWidth < 600) {
              crossAxisCount = 2;
              childAspectRatio = 0.9;
            } else if (constraints.maxWidth < 900) {
              crossAxisCount = 3;
              childAspectRatio = 0.8;
            } else {
              crossAxisCount = 4;
              childAspectRatio = 0.75;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: _artistAlbums.length,
              itemBuilder: (context, index) {
                final album = _artistAlbums[index];
                return _buildAlbumCard(theme, appState, album);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlbumCard(ThemeData theme, AppState appState, Album album) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.album(album: album),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album artwork
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: album.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(appState, album.imageUrl)!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.album,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.album,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // Album name
          Text(
            album.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Release year
          if (album.year != null)
            Text(
              album.year.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(
    ThemeData theme,
    AppState appState,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  l10n.popularSongs,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Show all songs
                  },
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Track list
        Expanded(
          child: TrackListTemplate(
            tracks: _popularTracks,
            emptyStateTitle: l10n.noSongsFound,
            emptyStateMessage: l10n.artistHasNoSongsYet,
            showTrackNumber: true,
            showArtist: false,
            showAlbum: true,
            showArtwork: true,
            onTrackTap: (track, index) async {
              await appState.playPlaylist(_popularTracks, index);
            },
          ),
        ),
      ],
    );
  }

  int _getTotalTracks() {
    return _popularTracks.length;
  }
}
