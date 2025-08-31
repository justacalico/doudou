import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';

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
    final albumTracks = await appState.getAlbumTracks(widget.album.id);
    
    setState(() {
      tracks = albumTracks;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(widget.album.name),
            backgroundColor: CupertinoColors.systemPurple.resolveFrom(context),
            stretch: true,
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.systemPurple.withOpacity(0.8),
                    CupertinoColors.systemPurple.withOpacity(0.6),
                  ],
                ),
              ),
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
                                  imageUrl: appState.jellyfinService.getImageUrl(
                                    widget.album.imageUrl!,
                                    width: 400,
                                    height: 400,
                                  ),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                                    child: const Center(
                                      child: CupertinoActivityIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                                    child: const Icon(CupertinoIcons.music_albums, size: 80),
                                  ),
                                )
                              : Container(
                                  color: CupertinoColors.systemGrey4.resolveFrom(context),
                                  child: const Icon(CupertinoIcons.music_albums, size: 80),
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
                      if (widget.album.year != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.album.year.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.white,
                          ),
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
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            )
          else if (tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.secondaryLabel),
                    SizedBox(height: 16),
                    Text(
                      'No tracks found',
                      style: TextStyle(fontSize: 18, color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              onPressed: () => _playAllTracks(),
                              color: CupertinoColors.systemPurple,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.play_arrow, color: CupertinoColors.white),
                                  SizedBox(width: 8),
                                  Text('Play All', style: TextStyle(color: CupertinoColors.white)),
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
                                  Icon(CupertinoIcons.shuffle, color: CupertinoColors.systemPurple.resolveFrom(context)),
                                  const SizedBox(width: 8),
                                  Text('Shuffle', style: TextStyle(color: CupertinoColors.systemPurple.resolveFrom(context))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final track = tracks[index - 1];
                  return TrackListItem(
                    track: track,
                    trackNumber: index,
                    onTap: () => _playTrack(track, index - 1),
                  );
                },
                childCount: tracks.length + 1,
              ),
            ),
        ],
      ),
    );
  }

  void _playTrack(Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(tracks, index);
    
    _showSnackBar('Playing: ${track.name}');
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
      
      _showSnackBar('Playing shuffled playlist');
    }
  }

  void _showSnackBar(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class TrackListItem extends StatelessWidget {
  final Track track;
  final int trackNumber;
  final VoidCallback onTap;

  const TrackListItem({
    super.key,
    required this.track,
    required this.trackNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              track.trackNumber?.toString() ?? trackNumber.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
        title: Text(
          track.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artistName != null
            ? Text(
                track.artistName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: track.duration != null
            ? Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              )
            : null,
        onTap: onTap,
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
