import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';

// New screen for showing downloaded album details
class DownloadedAlbumDetailScreen extends StatelessWidget {
  final Album album;
  final List<Track> downloadedTracks;

  const DownloadedAlbumDetailScreen({
    super.key,
    required this.album,
    required this.downloadedTracks,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          album.name,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Album header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Album artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: album.imageUrl != null
                            ? Consumer<AppState>(
                                builder: (context, appState, child) {
                                  return CachedNetworkImage(
                                    imageUrl: appState.jellyfinService.getImageUrl(
                                      album.imageUrl!,
                                      width: 400,
                                      height: 400,
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        color: CupertinoColors.systemGrey,
                                        size: 64,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        color: CupertinoColors.systemGrey,
                                        size: 64,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  CupertinoIcons.music_albums,
                                  color: CupertinoColors.systemGrey,
                                  size: 64,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Album name
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Artist name
                    if (album.artistName != null) ...[
                      Text(
                        album.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Downloaded track count
                    Text(
                      '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Play button
                    if (downloadedTracks.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 18),
                              SizedBox(width: 8),
                              Text('Play Downloaded'),
                            ],
                          ),
                          onPressed: () => _playDownloadedTracks(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Downloaded tracks list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = downloadedTracks[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _playTrack(context, track, index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Track number
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  (index + 1).toString(),
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Downloaded indicator
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: Color(0xFF30D158),
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            // Track info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.name,
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (track.artistName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artistName!,
                                      style: const TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                },
                childCount: downloadedTracks.length,
              ),
            ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _playDownloadedTracks(BuildContext context) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, 0);
  }

  void _playTrack(BuildContext context, Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, index);
  }
}
