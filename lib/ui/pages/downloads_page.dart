import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Downloads page built from PageTemplate and a grid of track cards.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        final downloadedTracks = List<Track>.from(
          appState.tracks
              .where((t) => downloadService.isTrackDownloaded(t.id)),
        );

        return PageTemplate(
          title: l10n.downloads,
          subtitle: '${downloadedTracks.length} ${l10n.songs}',
          actions: [
            DesktopGlassButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () => appState.playPlaylist(downloadedTracks, 0)
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.playAll),
                ],
              ),
            ),
            const SizedBox(width: DesktopTheme.spacingSm),
            DesktopGlassButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () {
                      final shuffled = List<Track>.from(downloadedTracks)
                        ..shuffle();
                      appState.playPlaylist(shuffled, 0);
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shuffle_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.shuffleAll),
                ],
              ),
            ),
          ],
          child: downloadedTracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 64,
                        color: DesktopTheme.textMuted,
                      ),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.downloads,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: DesktopTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: DesktopTheme.spacingSm),
                      Text(
                        l10n.downloadSongsToListenOffline,
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: DesktopTheme.spacingMd,
                    mainAxisSpacing: DesktopTheme.spacingMd,
                  ),
                  itemCount: downloadedTracks.length,
                  itemBuilder: (context, index) {
                    final track = downloadedTracks[index];
                    final imageUrl = track.imageUrl != null
                        ? appState.getImageUrl(track.imageUrl!)
                        : null;
                    return MusicCard(
                      title: track.name,
                      subtitle: track.artistName ?? track.albumName ?? l10n.unknownArtist,
                      imageUrl: imageUrl,
                      size: 180,
                      placeholderIcon: Icons.music_note_rounded,
                      onTap: () => appState.playPlaylist(downloadedTracks, index),
                    );
                  },
                ),
        );
      },
    );
  }
}
