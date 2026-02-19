import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final playlists = List<Playlist>.from(appState.playlists)
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return PageTemplate(
            title: l10n.playlists,
            actions: [
              TextButton.icon(
                onPressed: () => appState.loadLibraryData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
            child: playlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_music_outlined, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          l10n.noPlaylistsAvailable,
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: AppTheme.spacingMd,
                      mainAxisSpacing: AppTheme.spacingMd,
                    ),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) {
                      final pl = playlists[i];
                      final imageUrl = pl.imageUrl != null ? appState.getImageUrl(pl.imageUrl!) : null;
                      return MusicCard(
                        title: pl.name,
                        subtitle: l10n.countSongs(pl.trackCount),
                        imageUrl: imageUrl,
                        size: 180,
                        onTap: () => NavigationService().navigateToPlaylist(pl),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
