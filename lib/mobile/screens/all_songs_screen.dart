import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// All songs screen with sorting
class AllSongsScreen extends StatefulWidget {
  const AllSongsScreen({super.key});

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  String _sortBy = 'name'; // name, artist, album

  List<Track> _sortTracks(List<Track> tracks) {
    final sorted = List<Track>.from(tracks);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'artist':
        sorted.sort((a, b) => (a.artistName ?? '').compareTo(b.artistName ?? ''));
        break;
      case 'album':
        sorted.sort((a, b) => (a.albumName ?? '').compareTo(b.albumName ?? ''));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tracks = _sortTracks(appState.tracks);

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Songs'),
            backgroundColor: AppTheme.background(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.sort_down),
              onPressed: () => _showSortOptions(context),
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Shuffle all button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => appState.shuffleAllTracks(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM,
                          horizontal: AppTheme.spacingL,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPink.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.shuffle,
                              size: 20,
                              color: AppTheme.accentPink,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Shuffle All (${tracks.length} songs)',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Track list
                TrackList(
                  tracks: tracks,
                  currentTrackId: appState.audioHandler?.currentTrack?.id,
                  getImageUrl: appState.getImageUrl,
                  onTrackTap: (track, index) {
                    appState.audioHandler?.playPlaylist(tracks, index);
                  },
                  onMoreTap: (track) => _showTrackOptions(context, appState, track),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 150),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sort By'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'name');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Name'),
                if (_sortBy == 'name') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'artist');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Artist'),
                if (_sortBy == 'artist') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'album');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Album'),
                if (_sortBy == 'album') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, AppState appState, Track track) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(track.name),
        message: Text(track.artistName ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: Text(
              track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.audioHandler?.addToQueue(track);
            },
            child: const Text('Play Next'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to playlist
            },
            child: const Text('Add to Playlist'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
