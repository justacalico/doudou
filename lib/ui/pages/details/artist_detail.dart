import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Text, TextButton, TextStyle, TextDecoration;
import 'package:provider/provider.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/ui/widgets/apple_design/liquid_glass.dart';
import 'package:doudou/ui/widgets/player/mini_player.dart';
import 'package:doudou/ui/widgets/track_list_item.dart';
import 'package:doudou/ui/widgets/cached_image_widget.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';
import 'package:doudou/ui/widgets/detail_track_view.dart';

/// Full-screen artist detail used when navigating from now-playing (e.g. "Go to Artist").
/// See [ArtistDetailsPage] in artist_details.dart for the overlay/list-style variant used
/// by the desktop detail overlay and media details.
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
          // Download all tracks
          if (_artistTracks.isNotEmpty)
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
      showAppleDialog(
        context: context,
        title: 'Download Started',
        content: Text(
          'Downloading ${_artistTracks.length} tracks by ${widget.artist.name}',
          style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }
  }

  void _addAllToQueue(AppState appState) {
    for (final track in _artistTracks) {
      appState.addToQueue(track);
    }

    // Show confirmation
    if (mounted) {
      showAppleDialog(
        context: context,
        title: 'Added to Queue',
        content: Text(
          'Added ${_artistTracks.length} tracks by ${widget.artist.name} to your queue',
          style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
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
        showAppleDialog(
          context: context,
          title: 'Radio Station Created',
          content: Text(
            'Started ${widget.artist.name} radio station with infinite playback',
            style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      }
    }
  }

  void _shareArtist(BuildContext context) {
    final artistInfo = '${widget.artist.name} - Check out this artist!';

    // For now, just show the artist info in a dialog
    // In a real app, you would use a share plugin like share_plus
    showAppleDialog(
      context: context,
      title: 'Share Artist',
      content: Text(
        artistInfo,
        style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
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
                        // Enhanced Header with glass effect
                        CupertinoSliverNavigationBar(
                          backgroundColor: Colors.transparent,
                          border: null,
                          stretch: true,
                          largeTitle: const Text(''),
                          leading: Container(
                            margin: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.pop(context),
                                    child: Icon(
                                      CupertinoIcons.chevron_left,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          trailing: Container(
                            margin: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _showArtistOptionsMenu(
                                      context,
                                      appState,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.ellipsis,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
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
                                // Main content
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Enhanced Artist Image with purple glow
                                      Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF8B5CF6,
                                              ).withOpacity(0.5),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              width: 2,
                                            ),
                                          ),
                                          child: ArtistImageWidget(
                                            imageUrl:
                                                widget.artist.imageUrl != null
                                                ? appState.getImageUrl(
                                                    widget.artist.imageUrl!,
                                                    width: 400,
                                                    height: 400,
                                                  )
                                                : null,
                                            size: 196,
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
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Enhanced Stats with glass effect
                                      if (!_isLoading)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 20,
                                              sigmaY: 20,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(
                                                      0.15,
                                                    ),
                                                    Colors.white.withOpacity(
                                                      0.05,
                                                    ),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_artistAlbums.isNotEmpty)
                                                    _buildStatItem(
                                                      '${_artistAlbums.length}',
                                                      _artistAlbums.length == 1
                                                          ? 'Album'
                                                          : 'Albums',
                                                      CupertinoIcons
                                                          .music_albums,
                                                      const Color(0xFF8B5CF6),
                                                    ),
                                                  if (_artistAlbums.isNotEmpty)
                                                    Container(
                                                      width: 1,
                                                      height: 32,
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                          ),
                                                    ),
                                                  _buildStatItem(
                                                    '${_artistTracks.length}',
                                                    _artistTracks.length == 1
                                                        ? 'Song'
                                                        : 'Songs',
                                                    CupertinoIcons.music_note,
                                                    const Color(0xFF06B6D4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ), // Enhanced Action Buttons Section
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
                                        child: CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              _playAllTracks(appState),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 20,
                                                sigmaY: 20,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF8B5CF6),
                                                          Color(0xFFEC4899),
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons.play_fill,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Play All',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              _shuffleTracks(appState),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 20,
                                                sigmaY: 20,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white.withOpacity(
                                                        0.15,
                                                      ),
                                                      Colors.white.withOpacity(
                                                        0.05,
                                                      ),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    width: 1,
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
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Shuffle',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ), // Loading or Content
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF8B5CF6,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF8B5CF6,
                                          ).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.music_albums_fill,
                                        color: Color(0xFF8B5CF6),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Albums',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  itemCount: _artistAlbums.length,
                                  itemBuilder: (context, index) {
                                    final album = _artistAlbums[index];
                                    return _buildEnhancedAlbumCard(
                                      album,
                                      appState,
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFEC4899,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFEC4899,
                                          ).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.music_note_list,
                                        color: Color(0xFFEC4899),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Popular Tracks',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
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
              ),
            ),
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
                        const Color(0xFF8B5CF6).withOpacity(0.3),
                        const Color(0xFFEC4899).withOpacity(0.2),
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
                                  const Color(0xFF8B5CF6).withOpacity(0.3),
                                  const Color(0xFFEC4899).withOpacity(0.2),
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
                                const Color(0xFF8B5CF6).withOpacity(0.3),
                                const Color(0xFFEC4899).withOpacity(0.2),
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
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          album.year.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B5CF6),
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
      showDownloadButton: true,
      showFavoriteButton: true,
    );
  }
}
