import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../widgets/mini_player.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<Track> _artistTracks = [];
  List<Album> _artistAlbums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistContent();
  }

  void _loadArtistContent() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all tracks by this artist
      final allTracks = appState.tracks;
      _artistTracks = allTracks.where((track) => 
        track.artistName?.toLowerCase() == widget.artist.name.toLowerCase()
      ).toList();

      // Get all albums by this artist
      final allAlbums = appState.albums;
      _artistAlbums = allAlbums.where((album) => 
        album.artistName?.toLowerCase() == widget.artist.name.toLowerCase()
      ).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playAllTracks(AppState appState) async {
    if (_artistTracks.isNotEmpty) {
      await appState.audioHandler?.playPlaylist(_artistTracks, 0);
    }
  }

  void _shuffleTracks(AppState appState) async {
    if (_artistTracks.isNotEmpty) {
      final shuffledTracks = List<Track>.from(_artistTracks)..shuffle();
      await appState.audioHandler?.playPlaylist(shuffledTracks, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000), // Pure black for OLED
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Custom Header with Hero Image
                  SliverAppBar(
                    expandedHeight: 400,
                    backgroundColor: const Color(0xFF000000),
                    pinned: true,
                    stretch: true,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF1C1C1E),
                          width: 1,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          color: Color(0xFFFFFFFF),
                          size: 20,
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background blur effect
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF1C1C1E).withOpacity(0.3),
                                  const Color(0xFF000000).withOpacity(0.8),
                                  const Color(0xFF000000),
                                ],
                              ),
                            ),
                          ),
                          // Artist image and info
                          Positioned(
                            bottom: 60,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                // Artist Image with glow effect
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF32D74B).withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: widget.artist.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: appState.jellyfinService.getImageUrl(
                                              widget.artist.imageUrl!,
                                              width: 360,
                                              height: 360,
                                            ),
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: const Color(0xFF1C1C1E),
                                              child: const Center(
                                                child: CupertinoActivityIndicator(
                                                  color: Color(0xFF8E8E93),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: const Color(0xFF1C1C1E),
                                              child: const Icon(
                                                CupertinoIcons.person,
                                                color: Color(0xFF8E8E93),
                                                size: 80,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFF1C1C1E),
                                            child: const Icon(
                                              CupertinoIcons.person,
                                              color: Color(0xFF8E8E93),
                                              size: 80,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Artist Name
                                Text(
                                  widget.artist.name,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFFFFF),
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 8,
                                        color: Color(0xFF000000),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // Stats with better design
                                if (!_isLoading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF000000).withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFF1C1C1E),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${_artistAlbums.length} ${_artistAlbums.length == 1 ? 'Album' : 'Albums'} • ${_artistTracks.length} ${_artistTracks.length == 1 ? 'Song' : 'Songs'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF8E8E93),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action Buttons Section
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Play and Shuffle buttons
                          if (_artistTracks.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF32D74B), Color(0xFF30D158)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF32D74B).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoButton(
                                      onPressed: () => _playAllTracks(appState),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.play_fill,
                                            color: Color(0xFFFFFFFF),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Play All',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFFFFFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1C1E),
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: const Color(0xFF2C2C2E),
                                        width: 1,
                                      ),
                                    ),
                                    child: CupertinoButton(
                                      onPressed: () => _shuffleTracks(appState),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.shuffle,
                                            color: Color(0xFFFFFFFF),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Shuffle',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFFFFFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Loading or Content
                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CupertinoActivityIndicator(
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    )
                  else ...[
                    // Albums Section
                    if (_artistAlbums.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.music_albums_fill,
                                  color: Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Albums',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 240,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _artistAlbums.length,
                            itemBuilder: (context, index) {
                              final album = _artistAlbums[index];
                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 16),
                                child: _buildAlbumTile(album, appState),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    
                    // Popular Tracks Section
                    if (_artistTracks.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF453A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFF453A).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.music_note_list,
                                  color: Color(0xFFFF453A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Popular Tracks',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = _artistTracks[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: _buildTrackTile(track, appState, index + 1),
                            );
                          },
                          childCount: _artistTracks.length,
                        ),
                      ),
                    ],
                    
                    // Empty State
                    if (_artistTracks.isEmpty && _artistAlbums.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.music_note,
                                size: 80,
                                color: Color(0xFF333333),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No content found for ${widget.artist.name}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFFFFF),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'This artist\'s music will appear here once it\'s loaded.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF8E8E93),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  
                  // Bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
              // Mini Player
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumTile(Album album, AppState appState) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // TODO: Navigate to album details
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF2C2C2E),
                  child: album.imageUrl != null
                      ? Image.network(
                          appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 300,
                            height: 300,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              CupertinoIcons.music_albums,
                              color: CupertinoColors.systemGrey2,
                              size: 40,
                            );
                          },
                        )
                      : const Icon(
                          CupertinoIcons.music_albums,
                          color: CupertinoColors.systemGrey2,
                          size: 40,
                        ),
                ),
              ),
            ),
            // Album Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artistName ?? 'Unknown Artist',
                    style: const TextStyle(
                      fontSize: 12,
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
    );
  }

  Widget _buildTrackTile(Track track, AppState appState, int trackNumber) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        // Find the track index in the artist tracks list
        final trackIndex = _artistTracks.indexOf(track);
        if (trackIndex != -1) {
          await appState.audioHandler?.playPlaylist(_artistTracks, trackIndex);
        } else {
          // Fallback to playing single track
          await appState.playTrack(track);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Track Number
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                trackNumber.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Album Art
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2C2C2E),
                child: track.imageUrl != null
                    ? Image.network(
                        appState.jellyfinService.getImageUrl(
                          track.imageUrl!,
                          width: 100,
                          height: 100,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.systemGrey2,
                            size: 20,
                          );
                        },
                      )
                    : const Icon(
                        CupertinoIcons.music_note,
                        color: CupertinoColors.systemGrey2,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Track Info
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
                  if (track.albumName != null)
                    Text(
                      track.albumName!,
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
            
            // More Options
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _showTrackOptions(context, track, appState);
              },
              child: const Icon(
                CupertinoIcons.ellipsis,
                color: CupertinoColors.systemGrey2,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          track.name,
          style: const TextStyle(fontSize: 16),
        ),
        message: Text(
          track.artistName ?? 'Unknown Artist',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, track, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Add to Playlist'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  track.isFavorite ? CupertinoIcons.heart_slash : CupertinoIcons.heart,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(width: 8),
                Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Track track, AppState appState) {
    final playlists = appState.playlists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add to Playlist'),
        message: Text('Select a playlist to add "${track.name}" to:'),
        actions: [
          // Show existing playlists
          ...playlists.map((playlist) => CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final success = await appState.addToPlaylist(playlist.id, track.id);
              if (context.mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text(success ? 'Success' : 'Error'),
                    content: Text(success 
                        ? 'Added "${track.name}" to "${playlist.name}"'
                        : 'Failed to add "${track.name}" to "${playlist.name}"'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_list, color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          // Create new playlist option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createNewPlaylist(context, track, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Create New Playlist'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _createNewPlaylist(BuildContext context, Track track, AppState appState) {
    final TextEditingController controller = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your new playlist:'),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Playlist name',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final success = await appState.createPlaylist(controller.text.trim());
                if (success && context.mounted) {
                  final newPlaylist = appState.playlists.firstWhere(
                    (p) => p.name == controller.text.trim(),
                  );
                  final addSuccess = await appState.addToPlaylist(newPlaylist.id, track.id);
                  if (context.mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(addSuccess ? 'Success' : 'Partial Success'),
                        content: Text(addSuccess 
                            ? 'Created playlist "${controller.text.trim()}" and added "${track.name}" to it.'
                            : 'Created playlist "${controller.text.trim()}" but failed to add the song.'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
