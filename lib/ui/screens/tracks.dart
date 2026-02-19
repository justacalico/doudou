import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../theme.dart';
import '../widgets/page_template.dart';
import '../widgets/track_tile.dart';

class TracksScreen extends StatelessWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return PageTemplate(
            title: l10n.songs,
            actions: [
              TextButton.icon(
                onPressed: () => appState.loadLibraryData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
            child: appState.tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_note_outlined, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          l10n.noSongsFound,
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.yourMusicCollection,
                          style: TextStyle(fontSize: 14, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                    itemCount: appState.tracks.length,
                    itemBuilder: (context, i) {
                      final track = appState.tracks[i];
                      return TrackTile(
                        track: track,
                        index: i,
                        playlist: appState.tracks,
                        showTrackNumber: true,
                        showArtwork: true,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
