import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../widgets/mini_player.dart';
import '../../../widgets/cached_image_widget.dart';

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
                  // Custom Header with Hero Image (Cupertino version)
                  CupertinoSliverNavigationBar(
                    backgroundColor: const Color(0xFF000000),
                    border: null,
                    stretch: true,
                    largeTitle: const Text(''),
                    leading: Container(
                      margin: const EdgeInsets.all(4),
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
                  ),
                  
                  // Hero Section
                  SliverToBoxAdapter(
                    child: Container(
                      height: 350,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            child: ArtistImageWidget(
                              imageUrl: widget.artist.imageUrl != null
                                  ? appState.jellyfinService.getImageUrl(
                                      widget.artist.imageUrl!,
                                      width: 360,
                                      height: 360,
                                    )
                                  : null,
                              size: 180,
                              isCircular: true,
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
                          const SizedBox(height: 12),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          // TODO: Navigate to album details
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Art
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: AlbumArtWidget(
                    imageUrl: album.imageUrl != null
                        ? appState.jellyfinService.getImageUrl(
                            album.imageUrl!,
                            width: 320,
                            height: 320,
                          )
                        : null,
                    size: 160,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                ),
              ),
              // Album Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF000000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (album.year != null)
                      Text(
                        album.year.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackTile(Track track, AppState appState, int trackNumber) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(CupertinoIcons.add, size: 18, color: Color(0xFFFFFFFF)),
                SizedBox(width: 8),
                Text('Add to Queue', style: TextStyle(color: Color(0xFFFFFFFF))),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addToQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(CupertinoIcons.play_arrow, size: 18, color: Color(0xFFFFFFFF)),
                SizedBox(width: 8),
                Text('Play Next', style: TextStyle(color: Color(0xFFFFFFFF))),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addNextInQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: Row(
              children: [
                Icon(
                  track.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 18,
                  color: track.isFavorite ? const Color(0xFFFF453A) : const Color(0xFFFFFFFF),
                ),
                const SizedBox(width: 8),
                Text(
                  track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
          ),
        ],
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final trackIndex = _artistTracks.indexOf(track);
            if (trackIndex != -1) {
              await appState.audioHandler?.playPlaylist(_artistTracks, trackIndex);
            } else {
              await appState.playTrack(track);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Track Number with play icon overlay
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        trackNumber.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Album Art
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1C1C1E),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: track.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: appState.jellyfinService.getImageUrl(
                              track.imageUrl!,
                              width: 112,
                              height: 112,
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
                                CupertinoIcons.music_note,
                                color: Color(0xFF8E8E93),
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFF8E8E93),
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                
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
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (track.albumName != null)
                        Text(
                          track.albumName!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // Duration and favorite button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (track.duration != null)
                      Text(
                        _formatDuration(Duration(milliseconds: track.duration!)),
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => appState.toggleFavorite(track),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: track.isFavorite 
                              ? const Color(0xFFFF453A).withOpacity(0.1)
                              : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: track.isFavorite 
                                ? const Color(0xFFFF453A).withOpacity(0.3)
                                : const Color(0xFF2C2C2E),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          track.isFavorite 
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: track.isFavorite 
                              ? const Color(0xFFFF453A)
                              : const Color(0xFF8E8E93),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
