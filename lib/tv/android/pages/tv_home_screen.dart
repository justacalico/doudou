import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../widgets/tv_album_card.dart';
import '../widgets/tv_focus_border.dart';

/// Android TV Home Screen
/// 
/// Provides a 10-foot UI optimized for TV viewing with D-pad navigation
class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  int _selectedCategoryIndex = 0;
  
  final List<String> _categories = [
    'Recent',
    'Albums',
    'Artists',
    'Playlists',
    'Tracks',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, appState),
              _buildCategoryTabs(),
              Expanded(
                child: _buildContent(appState),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.shade900.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // App Logo/Title
          const Icon(
            Icons.music_note,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(width: 20),
          const Text(
            'Doudou',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // User info
          if (appState.isLoggedIn)
            Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 40,
                  color: Colors.white70,
                ),
                const SizedBox(width: 12),
                Text(
                  appState.jellyfinService.serverUrl ?? 'Connected',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TVFocusBorder(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purple.shade700
                        : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.purple.shade300
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 22,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent(AppState appState) {
    if (appState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.purple,
        ),
      );
    }

    switch (_selectedCategoryIndex) {
      case 0:
        return _buildRecentTracks(appState);
      case 1:
        return _buildAlbums(appState);
      case 2:
        return _buildArtists(appState);
      case 3:
        return _buildPlaylists(appState);
      case 4:
        return _buildTracks(appState);
      default:
        return const Center(
          child: Text(
            'Select a category',
            style: TextStyle(color: Colors.white70, fontSize: 24),
          ),
        );
    }
  }

  Widget _buildRecentTracks(AppState appState) {
    if (appState.recentTracks.isEmpty) {
      return _buildEmptyState('No recent tracks');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: appState.recentTracks.length,
      itemBuilder: (context, index) {
        final track = appState.recentTracks[index];
        return TVAlbumCard(
          title: track.name,
          subtitle: track.artistName ?? 'Unknown Artist',
          imageUrl: track.albumId != null
              ? appState.getImageUrl(track.albumId!)
              : null,
          onTap: () => _playTrack(appState, track.id),
        );
      },
    );
  }

  Widget _buildAlbums(AppState appState) {
    if (appState.albums.isEmpty) {
      return _buildEmptyState('No albums found');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: appState.albums.length,
      itemBuilder: (context, index) {
        final album = appState.albums[index];
        return TVAlbumCard(
          title: album.name,
          subtitle: album.artistName ?? 'Unknown Artist',
          imageUrl: appState.getImageUrl(album.id),
          onTap: () => _playAlbum(appState, album.id),
        );
      },
    );
  }

  Widget _buildArtists(AppState appState) {
    if (appState.artists.isEmpty) {
      return _buildEmptyState('No artists found');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.7,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: appState.artists.length,
      itemBuilder: (context, index) {
        final artist = appState.artists[index];
        return TVAlbumCard(
          title: artist.name,
          subtitle: '${artist.albumCount ?? 0} albums',
          imageUrl: appState.getImageUrl(artist.id),
          isCircular: true,
          onTap: () => _viewArtist(appState, artist.id),
        );
      },
    );
  }

  Widget _buildPlaylists(AppState appState) {
    if (appState.playlists.isEmpty) {
      return _buildEmptyState('No playlists found');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: appState.playlists.length,
      itemBuilder: (context, index) {
        final playlist = appState.playlists[index];
        return TVAlbumCard(
          title: playlist.name,
          subtitle: 'Playlist',
          imageUrl: appState.getImageUrl(playlist.id),
          onTap: () => _playPlaylist(appState, playlist.id),
        );
      },
    );
  }

  Widget _buildTracks(AppState appState) {
    if (appState.tracks.isEmpty) {
      return _buildEmptyState('No tracks found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(48),
      itemCount: appState.tracks.length,
      itemBuilder: (context, index) {
        final track = appState.tracks[index];
        return TVFocusBorder(
          child: InkWell(
            onTap: () => _playTrack(appState, track.id),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Track number
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artistName ?? 'Unknown Artist',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Duration
                  if (track.duration != null)
                    Text(
                      _formatDuration(track.duration!),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 100,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  void _playTrack(AppState appState, String trackId) {
    final track = appState.tracks.firstWhere((t) => t.id == trackId);
    appState.playTrack(track);
  }

  void _playAlbum(AppState appState, String albumId) {
    appState.playAlbum(albumId);
  }

  void _playPlaylist(AppState appState, String playlistId) {
    appState.playPlaylist(playlistId);
  }

  void _viewArtist(AppState appState, String artistId) {
    // Navigate to artist details
    // TODO: Implement artist details screen for TV
  }
}
