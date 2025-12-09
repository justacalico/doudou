import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../partials/player/mini_player.dart';
import '../partials/tracks/track_list_item.dart';

class SongsView extends StatelessWidget {
  const SongsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.tracks.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

        if (appState.tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.systemGrey),
                const SizedBox(height: 16),
                Text(
                  l10n.noSongsFound,
                  style: const TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Container(
              color: const Color(0xFF000000), // Dark background
              child: CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () => appState.loadLibraryData(),
                  ),
                  // Header with Play and Shuffle buttons
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(25),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.play_fill, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.playAll,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                if (appState.tracks.isNotEmpty) {
                                  appState.playPlaylist(appState.tracks, 0);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(25),
                              color: const Color(0xFF2C2C2E),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.shuffle, color: CupertinoColors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.shuffle,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                if (appState.tracks.isNotEmpty) {
                                  final shuffledTracks = List<Track>.from(appState.tracks)..shuffle();
                                  appState.playPlaylist(shuffledTracks, 0);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Songs list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = appState.tracks[index];
                        return TrackListItem(
                          track: track,
                          onTap: () {
                            appState.playPlaylist(appState.tracks, index);
                          },
                          showAlbumArt: false,
                          showTrackNumber: false,
                          showDuration: true,
                          showDownloadButton: true,
                          showFavoriteButton: true,
                        );
                      },
                      childCount: appState.tracks.length,
                    ),
                  ),
                  // Add some bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
            // Mini player at bottom
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        );
      },
    );
  }
}
