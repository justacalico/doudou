import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Favorites screen - Apple Music style
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final favorites = appState.favoriteTracks;

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Favorites'),
            backgroundColor: AppTheme.background(context),
            border: null,
          ),
          child: SafeArea(
            child: favorites.isEmpty
                ? _buildEmptyState(context)
                : CustomScrollView(
                    slivers: [
                      // Shuffle button
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => appState.shuffleFavoriteTracks(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingM,
                                horizontal: AppTheme.spacingL,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemPink.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.shuffle,
                                    size: 20,
                                    color: CupertinoColors.systemPink,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'Shuffle (${favorites.length} songs)',
                                    style: const TextStyle(
                                      fontSize: AppTheme.fontSizeBody,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemPink,
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
                        tracks: favorites,
                        currentTrackId: appState.audioHandler?.currentTrack?.id,
                        getImageUrl: appState.getImageUrl,
                        onTrackTap: (track, index) {
                          appState.audioHandler?.playPlaylist(favorites, index);
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.heart,
            size: 64,
            color: AppTheme.textSecondary(context),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Favorites Yet',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle3,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Songs you love will appear here',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
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
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: const Text('Remove from Favorites'),
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
