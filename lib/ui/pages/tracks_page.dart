import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';

import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/track_list.dart';

/// Tracks page built from PageTemplate and TrackListTemplate.
class TracksPage extends StatefulWidget {
  const TracksPage({super.key});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.tracks.isEmpty) appState.loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final visibleTracks = appState.isYoutubeMusic
            ? appState.favoriteTracks
            : appState.tracks;
        return PageTemplate(
          title: l10n.songs,
          child: TrackListTemplate(
            tracks: visibleTracks,
            emptyStateTitle: l10n.noSongsFound,
            emptyStateMessage: l10n.yourMusicCollection,
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
