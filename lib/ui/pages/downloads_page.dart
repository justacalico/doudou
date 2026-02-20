import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/track_list.dart';

/// Downloads page built from PageTemplate and TrackListTemplate.
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
          child: TrackListTemplate(
            tracks: downloadedTracks,
            emptyStateTitle: l10n.downloads,
            emptyStateMessage: l10n.downloadSongsToListenOffline,
            showTrackNumber: true,
            showArtist: true,
            showAlbum: true,
            showArtwork: true,
          ),
        );
      },
    );
  }
}
