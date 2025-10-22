import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../partials/player/mini_player.dart';
import '../../../widgets/cached_image_widget.dart';
import '../../shared/detail_track_view.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

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
      _artistTracks = allTracks
          .where(
            (track) =>
                track.artistName?.toLowerCase() ==
                widget.artist.name.toLowerCase(),
          )
          .toList();

      // Get all albums by this artist
      final allAlbums = appState.albums;
      _artistAlbums = allAlbums
          .where(
            (album) =>
                album.artistName?.toLowerCase() ==
                widget.artist.name.toLowerCase(),
          )
          .toList();

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
              // Background gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1C1C1E).withOpacity(0.1),
                      const Color(0xFF000000).withOpacity(0.95),
                      const Color(0xFF000000),
                    ],
                  ),
                ),
              ),

              CustomScrollView(
                slivers: [
                  // Enhanced Header
                  CupertinoSliverNavigationBar(
                    backgroundColor: const Color(0xFF000000).withOpacity(0.1),
                    border: null,
                    stretch: true,
                    largeTitle: const Text(''),
                    leading: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1C1C1E).withOpacity(0.8),
                            const Color(0xFF2C2C2E).withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF3C3C3E).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
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
                    trailing: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1C1C1E).withOpacity(0.8),
                            const Color(0xFF2C2C2E).withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF3C3C3E).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showArtistOptionsMenu(context, appState),
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          color: Color(0xFFFFFFFF),
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Enhanced Hero Section
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 400,
                      child: Stack(
                        children: [
                          // Background pattern
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.0,
                                  colors: [
                                    const Color(0xFF8E4EC6).withOpacity(0.1),
                                    const Color(0xFF000000).withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Main content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Enhanced Artist Image
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF8E4EC6).withOpacity(0.3),
                                      const Color(0xFFBF5AF2).withOpacity(0.2),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8E4EC6,
                                      ).withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFF8E4EC6,
                                      ).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ArtistImageWidget(
                                    imageUrl: widget.artist.imageUrl != null
                                        ? appState.getImageUrl(
                                            widget.artist.imageUrl!,
                                            width: 400,
                                            height: 400,
                                          )
                                        : null,
                                    size: 184,
                                    isCircular: true,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Enhanced Artist Name
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  widget.artist.name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFFFFF),
                                    letterSpacing: -0.5,
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
                              ),

                              const SizedBox(height: 16),

                              // Enhanced Stats
                              if (!_isLoading)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF1C1C1E,
                                        ).withOpacity(0.8),
                                        const Color(
                                          0xFF2C2C2E,
                                        ).withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF3C3C3E,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF000000,
                                        ).withOpacity(0.2),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatItem(
                                        '${_artistAlbums.length}',
                                        _artistAlbums.length == 1
                                            ? 'Album'
                                            : 'Albums',
                                        CupertinoIcons.music_albums,
                                        const Color(0xFF30D158),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 32,
                                        color: const Color(
                                          0xFF3C3C3E,
                                        ).withOpacity(0.5),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      _buildStatItem(
                                        '${_artistTracks.length}',
                                        _artistTracks.length == 1
                                            ? 'Song'
                                            : 'Songs',
                                        CupertinoIcons.music_note,
                                        const Color(0xFF007AFF),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enhanced Action Buttons Section
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        children: [
                          // Enhanced Play and Shuffle buttons
                          if (_artistTracks.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF30D158),
                                          Color(0xFF32ADE6),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF30D158,
                                          ).withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoButton(
                                      onPressed: () => _playAllTracks(appState),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.play_fill,
                                            color: Color(0xFFFFFFFF),
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Play All',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFFFFFFF),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(
                                            0xFF1C1C1E,
                                          ).withOpacity(0.8),
                                          const Color(
                                            0xFF2C2C2E,
                                          ).withOpacity(0.6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF3C3C3E,
                                        ).withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF000000,
                                          ).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CupertinoButton(
                                      onPressed: () => _shuffleTracks(appState),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.shuffle,
                                            color: Color(0xFFFFFFFF),
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Shuffle',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFFFFFFF),
                                              letterSpacing: -0.2,
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
                                  color: const Color(
                                    0xFF007AFF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withOpacity(0.2),
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
                          height: 300,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _artistAlbums.length,
                            itemBuilder: (context, index) {
                              final album = _artistAlbums[index];
                              return _buildEnhancedAlbumCard(album, appState);
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
                                  color: const Color(
                                    0xFFFF453A,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF453A,
                                    ).withOpacity(0.2),
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
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final track = _artistTracks[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: index < _artistTracks.length - 1
                                  ? 12
                                  : 20,
                            ),
                            child: _buildEnhancedTrackItem(
                              track,
                              appState,
                              index,
                            ),
                          );
                        }, childCount: _artistTracks.length),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  // Helper method for building stat items
  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFFFFF),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Enhanced album card
  Widget _buildEnhancedAlbumCard(Album album, AppState appState) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => DetailTrackView.album(album),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E).withOpacity(0.6),
                const Color(0xFF2C2C2E).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF3C3C3E).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.3),
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album artwork
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF30D158).withOpacity(0.3),
                        const Color(0xFF32ADE6).withOpacity(0.2),
                      ],
                    ),
                  ),
                  child: album.imageUrl != null
                      ? CachedImageWidget(
                          imageUrl: appState.getImageUrl(
                            album.imageUrl!,
                            width: 360,
                            height: 360,
                          ),
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF30D158).withOpacity(0.3),
                                  const Color(0xFF32ADE6).withOpacity(0.2),
                                ],
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              size: 64,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF30D158).withOpacity(0.3),
                                const Color(0xFF32ADE6).withOpacity(0.2),
                              ],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_albums,
                            size: 64,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                ),
              ),

              // Album info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.year != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          album.year.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF30D158),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced track item
  Widget _buildEnhancedTrackItem(Track track, AppState appState, int index) {
    return GestureDetector(
      onTap: () async {
        final trackIndex = _artistTracks.indexOf(track);
        if (trackIndex != -1) {
          await appState.audioHandler?.playPlaylist(_artistTracks, trackIndex);
        } else {
          await appState.playTrack(track);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1C1C1E).withOpacity(0.4),
              const Color(0xFF2C2C2E).withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3C3C3E).withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Track number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Track artwork
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF007AFF).withOpacity(0.3),
                    const Color(0xFF5856D6).withOpacity(0.2),
                  ],
                ),
              ),
              child: track.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedImageWidget(
                        imageUrl: appState.getImageUrl(
                          track.imageUrl!,
                          width: 96,
                          height: 96,
                        ),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF007AFF).withOpacity(0.3),
                                const Color(0xFF5856D6).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: Color(0xFFFFFFFF),
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF007AFF).withOpacity(0.3),
                            const Color(0xFF5856D6).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.music_note,
                        color: Color(0xFFFFFFFF),
                        size: 20,
                      ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: -0.2,
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
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Track actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (track.isFavorite)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      color: Color(0xFFFF453A),
                      size: 16,
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: Color(0xFF007AFF),
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
