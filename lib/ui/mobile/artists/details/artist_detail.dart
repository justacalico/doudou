import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:provider/provider.dart';
import '../../../../providers/app_state.dart';
import '../../../../models/jellyfin_models.dart';
import '../../../../services/base_service.dart';
import '../../../../utils/display_utils.dart';
import '../../widgets/apple_design/liquid_glass.dart';
import '../../partials/player/mini_player.dart';
import '../../partials/tracks/track_list_item.dart';
import '../../widgets/cached_image_widget.dart';
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
  String _selectedTab = 'albums'; // 'albums' | 'songs'

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
      final isSoundCloud = appState.mediaServiceManager.currentServerType ==
          ServerType.soundcloud;
      final isYouTubeMusic = appState.mediaServiceManager.currentServerType ==
          ServerType.youtubeMusic;

      if (isSoundCloud) {
        _artistAlbums = [];
        _artistTracks = await appState.getArtistTracks(widget.artist);
      } else if (isYouTubeMusic) {
        _artistTracks = await appState.getArtistTracks(widget.artist);
        _artistAlbums = albumsFromTracks(_artistTracks, artistName: widget.artist.name, artistId: widget.artist.id);
      } else {
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
      }

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

  void _showArtistOptionsMenu(BuildContext context, AppState appState) {
    final summary = _artistAlbums.isNotEmpty
        ? '${_artistTracks.length} ${_artistTracks.length == 1 ? 'song' : 'songs'} • ${_artistAlbums.length} ${_artistAlbums.length == 1 ? 'album' : 'albums'}'
        : '${_artistTracks.length} ${_artistTracks.length == 1 ? 'song' : 'songs'}';

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(widget.artist.name, style: const TextStyle(fontSize: 16)),
        message: Text(summary, style: const TextStyle(fontSize: 14)),
        actions: [
          // Download all tracks (disabled for SoundCloud)
          if (_artistTracks.isNotEmpty &&
              appState.mediaServiceManager.currentServerType !=
                  ServerType.soundcloud &&
              appState.mediaServiceManager.currentServerType !=
                  ServerType.youtubeMusic)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _downloadAllTracks(appState);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.arrow_down_circle,
                    size: 18,
                    color: Color(0xFF06B6D4),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Download All',
                    style: TextStyle(color: Color(0xFF06B6D4)),
                  ),
                ],
              ),
            ),
          // Add all to queue
          if (_artistTracks.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _addAllToQueue(appState);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus, size: 18, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Text(
                    'Add All to Queue',
                    style: TextStyle(color: Color(0xFF8B5CF6)),
                  ),
                ],
              ),
            ),
          // Create artist radio/station (only for Jellyfin)
          if (_artistTracks.isNotEmpty &&
              appState.mediaServiceManager.currentServerType ==
                  ServerType.jellyfin)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _createArtistRadio(appState);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.infinite,
                    size: 18,
                    color: Color(0xFFEC4899),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Create Radio Station',
                    style: TextStyle(color: Color(0xFFEC4899)),
                  ),
                ],
              ),
            ),
          // Share artist
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareArtist(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 18, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text(
                  'Share Artist',
                  style: TextStyle(color: Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF8B5CF6)),
          ),
        ),
      ),
    );
  }

  void _downloadAllTracks(AppState appState) {
    for (final track in _artistTracks) {
      if (!appState.downloadService.isTrackDownloaded(track.id)) {
        appState.downloadService.downloadTrack(track);
      }
    }

    // Show confirmation
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Download Started'),
          content: Text(
            'Downloading ${_artistTracks.length} tracks by ${widget.artist.name}',
          ),
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

  void _addAllToQueue(AppState appState) {
    for (final track in _artistTracks) {
      appState.addToQueue(track);
    }

    // Show confirmation
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Added to Queue'),
          content: Text(
            'Added ${_artistTracks.length} tracks by ${widget.artist.name} to your queue',
          ),
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

  void _createArtistRadio(AppState appState) async {
    if (_artistTracks.isNotEmpty) {
      // Enable radio mode and start playing
      appState.enableRadioMode();
      final shuffledTracks = List<Track>.from(_artistTracks)..shuffle();
      await appState.audioHandler?.playPlaylist(shuffledTracks, 0);

      // Show confirmation
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Radio Station Created'),
            content: Text(
              'Started ${widget.artist.name} radio station with infinite playback',
            ),
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

  void _shareArtist(BuildContext context) {
    final artistInfo = '${widget.artist.name} - Check out this artist!';

    // For now, just show the artist info in a dialog
    // In a real app, you would use a share plugin like share_plus
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Share Artist'),
        content: Text(artistInfo),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return LiquidGradientBackground(
          child: CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            child: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        // Top header bar (gradient)
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => Navigator.pop(context),
                                      child: Icon(
                                        CupertinoIcons.chevron_left,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'DOUDOU',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.8),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const Spacer(),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _showArtistOptionsMenu(
                                            context,
                                            appState,
                                          ),
                                      child: Icon(
                                        CupertinoIcons.ellipsis,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Hero: image + info + follow inline
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: ArtistImageWidget(
                                      imageUrl:
                                          widget.artist.imageUrl != null
                                              ? appState.getImageUrl(
                                                  widget.artist.imageUrl!,
                                                  width: 224,
                                                  height: 224,
                                                )
                                              : null,
                                      size: 112,
                                      isCircular: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.artist.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      if (!_isLoading) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_artistAlbums.length} ${_artistAlbums.length == 1 ? 'Album' : 'Albums'} • ${_artistTracks.length} ${_artistTracks.length == 1 ? 'Song' : 'Songs'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (appState.mediaServiceManager
                                                  .currentServerType ==
                                              ServerType.soundcloud ||
                                          appState.mediaServiceManager
                                                  .currentServerType ==
                                              ServerType.youtubeMusic) ...[
                                        const SizedBox(height: 12),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () async {
                                            if (appState.isFollowingArtist(
                                                widget.artist.id)) {
                                              await appState.unfollowArtist(
                                                  widget.artist.id);
                                            } else {
                                              await appState.followArtist(
                                                  widget.artist);
                                            }
                                            if (mounted) setState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: appState.isFollowingArtist(
                                                      widget.artist.id)
                                                  ? const Color(0xFF2D2D2D)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: appState.isFollowingArtist(
                                                        widget.artist.id)
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  appState.isFollowingArtist(
                                                          widget.artist.id)
                                                      ? CupertinoIcons.checkmark
                                                      : CupertinoIcons
                                                          .person_add_solid,
                                                  size: 14,
                                                  color: appState
                                                          .isFollowingArtist(
                                                              widget.artist.id)
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  appState.isFollowingArtist(
                                                          widget.artist.id)
                                                      ? 'Following'
                                                      : 'Follow',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: appState
                                                            .isFollowingArtist(
                                                                widget.artist.id)
                                                        ? Colors.white
                                                        : Colors.black,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
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
                        // Action row: green play, Shuffle Play, more
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                if (_artistTracks.isNotEmpty)
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () =>
                                        _playAllTracks(appState),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1DB954),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1DB954)
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.play_fill,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                if (_artistTracks.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (_artistTracks.isNotEmpty)
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _shuffleTracks(appState),
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D2D2D)
                                              .withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.05),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.shuffle,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Shuffle Play',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      _showArtistOptionsMenu(
                                        context,
                                        appState,
                                      ),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D2D)
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.ellipsis,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Segmented tab control (Albums | Songs)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      onPressed: () =>
                                          setState(() => _selectedTab = 'albums'),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _selectedTab == 'albums'
                                              ? const Color(0xFF404040)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'ALBUMS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _selectedTab == 'albums'
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.5),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      onPressed: () =>
                                          setState(() => _selectedTab = 'songs'),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _selectedTab == 'songs'
                                              ? const Color(0xFF404040)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'SONGS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _selectedTab == 'songs'
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.5),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                          // Tab content: Albums (Latest Release list) or Songs
                          if (_selectedTab == 'albums') ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                                child: Text(
                                  'LATEST RELEASE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                            if (_artistAlbums.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final album = _artistAlbums[index];
                                    return _buildAlbumListRow(album, appState);
                                  },
                                  childCount: _artistAlbums.length,
                                ),
                              ),
                          ],
                          if (_selectedTab == 'songs' &&
                              _artistTracks.isNotEmpty)
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final track = _artistTracks[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                    bottom: index < _artistTracks.length - 1
                                        ? 12
                                        : 20,
                                  ),
                                  child: _buildEnhancedTrackItem(
                                    track,
                                    appState,
                                  ),
                                );
                              }, childCount: _artistTracks.length),
                            ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  // Album row for Latest Release list (redesign style)
  Widget _buildAlbumListRow(Album album, AppState appState) {
    final trackCount = _artistTracks
        .where((t) =>
            t.albumId == album.id ||
            (t.albumName?.toLowerCase() == album.name.toLowerCase()))
        .length;
    final yearStr = album.year?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: album.imageUrl != null
                    ? CachedImageWidget(
                        imageUrl: appState.getImageUrl(
                          album.imageUrl!,
                          width: 128,
                          height: 128,
                        ),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFF2D2D2D),
                          child: const Icon(
                            CupertinoIcons.music_albums,
                            color: Color(0xFF737373),
                            size: 28,
                          ),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: const Color(0xFF2D2D2D),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          color: Color(0xFF737373),
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$yearStr • $trackCount ${trackCount == 1 ? 'Track' : 'Tracks'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.music_albums_fill,
                size: 18,
                color: Colors.white.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced track item
  Widget _buildEnhancedTrackItem(Track track, AppState appState) {
    return TrackListItem(
      track: track,
      onTap: () async {
        final trackIndex = _artistTracks.indexOf(track);
        if (trackIndex != -1) {
          await appState.audioHandler?.playPlaylist(_artistTracks, trackIndex);
        } else {
          await appState.playTrack(track);
        }
      },
      showAlbumArt: true,
      showTrackNumber: false,
      showDuration: true,
      showDownloadButton: appState.mediaServiceManager.currentServerType !=
          ServerType.soundcloud &&
      appState.mediaServiceManager.currentServerType !=
          ServerType.youtubeMusic,
      showFavoriteButton: true,
    );
  }
}
