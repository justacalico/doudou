import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/jellyfin_models.dart';
import '../../../providers/app_state.dart';
import '../../partials/tracks/track_list_item.dart';
import '../../partials/player/mini_player.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Track> tracks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();

    // Ensure tracks are loaded first
    if (appState.tracks.isEmpty && !appState.isLoading) {
      await appState.loadLibraryData();
    }

    try {
      // First try to get tracks from the API
      final albumTracks = await appState.getAlbumTracks(widget.album.id);

      if (albumTracks.isNotEmpty) {
        setState(() {
          tracks = albumTracks;
          isLoading = false;
        });
        return;
      }

      // If no tracks from API, try filtering from existing tracks
      final allTracks = appState.tracks;
      final filteredTracks = allTracks
          .where(
            (track) =>
                track.albumId == widget.album.id ||
                track.albumName?.toLowerCase() ==
                    widget.album.name.toLowerCase(),
          )
          .toList();

      // Sort by track number if available
      filteredTracks.sort((a, b) {
        final aTrackNum = a.trackNumber ?? 0;
        final bTrackNum = b.trackNumber ?? 0;
        return aTrackNum.compareTo(bTrackNum);
      });

      setState(() {
        tracks = filteredTracks;
        isLoading = false;
      });
    } catch (e) {
      // Fallback to filtering existing tracks if API call fails
      final allTracks = appState.tracks;
      final filteredTracks = allTracks
          .where(
            (track) =>
                track.albumId == widget.album.id ||
                track.albumName?.toLowerCase() ==
                    widget.album.name.toLowerCase(),
          )
          .toList();

      // Sort by track number if available
      filteredTracks.sort((a, b) {
        final aTrackNum = a.trackNumber ?? 0;
        final bTrackNum = b.trackNumber ?? 0;
        return aTrackNum.compareTo(bTrackNum);
      });

      setState(() {
        tracks = filteredTracks;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(widget.album.name),
                backgroundColor: const Color(0xFF000000),
                stretch: true,
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF000000),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: widget.album.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: appState.jellyfinService
                                          .getImageUrl(
                                            widget.album.imageUrl!,
                                            width: 400,
                                            height: 400,
                                          ),
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => Container(
                                        color: CupertinoColors.systemGrey4
                                            .resolveFrom(context),
                                        child: const Center(
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: CupertinoColors.systemGrey4
                                                .resolveFrom(context),
                                            child: const Icon(
                                              CupertinoIcons.music_albums,
                                              size: 80,
                                            ),
                                          ),
                                    )
                                  : Container(
                                      color: CupertinoColors.systemGrey4
                                          .resolveFrom(context),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        size: 80,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.album.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.album.artistName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.album.artistName!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: CupertinoColors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (tracks.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.music_note,
                          size: 64,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tracks found',
                          style: TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                onPressed: () => _playAllTracks(),
                                color: const Color(0xFFFF453A),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.play_arrow,
                                      color: CupertinoColors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Play All',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CupertinoButton(
                                onPressed: () => _shuffleAllTracks(),
                                color: CupertinoColors.systemBackground,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.shuffle,
                                      color: const Color(0xFFFF453A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Shuffle',
                                      style: TextStyle(
                                        color: const Color(0xFFFF453A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (index == 1) {
                      // Check if all tracks are downloaded
                      final appState = context.read<AppState>();
                      final bool allTracksDownloaded =
                          tracks.isNotEmpty &&
                          tracks.every(
                            (track) => appState.downloadService
                                .isTrackDownloaded(track.id),
                          );

                      // Don't show download button if all tracks are already downloaded
                      if (allTracksDownloaded) {
                        return const SizedBox(height: 12);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Download button
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoButton(
                                color: CupertinoColors.systemGrey6.darkColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.cloud_download,
                                      size: 20,
                                      color: CupertinoColors.systemBlue,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Download Album',
                                      style: TextStyle(
                                        color: CupertinoColors.systemBlue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () => _downloadAlbum(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    }

                    final track = tracks[index - 2];
                    return TrackListItem(
                      track: track,
                      trackNumber: index - 1,
                      onTap: () => _playTrack(track, index - 2),
                      showAlbumArt: false,
                      showTrackNumber: true,
                      showDuration: true,
                      showDownloadButton: true,
                      showFavoriteButton: false,
                    );
                  }, childCount: tracks.length + 2),
                ),
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
    );
  }

  void _playTrack(Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(tracks, index);
  }

  void _playAllTracks() {
    if (tracks.isNotEmpty) {
      _playTrack(tracks.first, 0);
    }
  }

  void _shuffleAllTracks() {
    if (tracks.isNotEmpty) {
      final appState = context.read<AppState>();
      final shuffledTracks = List<Track>.from(tracks)..shuffle();
      appState.playPlaylist(shuffledTracks, 0);
    }
  }

  void _downloadAlbum() async {
    final appState = context.read<AppState>();

    if (tracks.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Empty Album'),
            content: Text(
              'The album "${widget.album.name}" has no tracks to download.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // Show confirmation dialog
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Download Album'),
          content: Text(
            'Download "${widget.album.name}" with ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}?',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Download'),
              onPressed: () {
                Navigator.of(context).pop();
                _startAlbumDownload(appState);
              },
            ),
          ],
        );
      },
    );
  }

  void _startAlbumDownload(AppState appState) async {
    int downloadedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;

    // Count already downloaded tracks
    for (final track in tracks) {
      if (appState.downloadService.isTrackDownloaded(track.id)) {
        skippedCount++;
      }
    }

    // Start downloading all tracks
    for (final track in tracks) {
      try {
        if (!appState.downloadService.isTrackDownloaded(track.id)) {
          await appState.downloadService.downloadTrack(track);
          downloadedCount++;
        }
      } catch (e) {
        failedCount++;
        if (kDebugMode) {
          print('Failed to start download for track ${track.name}: $e');
        }
      }
    }

    // Show completion message
    if (!mounted) return;
    String message;
    if (downloadedCount > 0) {
      message =
          'Started downloading $downloadedCount ${downloadedCount == 1 ? 'song' : 'songs'}';
      if (skippedCount > 0) {
        message += ', $skippedCount already downloaded';
      }
      if (failedCount > 0) {
        message += ', $failedCount failed to start';
      }
    } else if (skippedCount > 0) {
      if (skippedCount == tracks.length) {
        message = 'All songs in "${widget.album.name}" are already downloaded';
      } else {
        message = '$skippedCount songs already downloaded';
      }
    } else {
      message = 'Failed to start downloads';
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            downloadedCount > 0 || skippedCount == tracks.length
                ? 'Download Started'
                : 'Download Failed',
          ),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
