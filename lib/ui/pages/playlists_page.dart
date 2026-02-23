import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Playlists page built from PageTemplate and MusicCard grid.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Selector<AppState, List<Playlist>>(
      selector: (_, appState) => appState.playlists,
      builder: (context, playlists, child) {
        final sorted = List<Playlist>.from(playlists)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return PageTemplate(
          title: l10n.playlists,
          child: sorted.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music_outlined,
                          size: 64, color: DesktopTheme.textMuted),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.noPlaylistsAvailable,
                        style: TextStyle(
                            fontSize: 16, color: DesktopTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: DesktopTheme.spacingMd,
                    mainAxisSpacing: DesktopTheme.spacingMd,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final pl = sorted[index];
                    final appState = context.read<AppState>();
                    final imageUrl = pl.imageUrl != null
                        ? appState.getImageUrl(pl.imageUrl!)
                        : null;
                    return KeyedSubtree(
                      key: ValueKey(pl.id),
                      child: MusicCard(
                      title: pl.name,
                      subtitle: l10n.countSongs(pl.trackCount),
                      imageUrl: imageUrl,
                      size: 180,
                      onTap: () =>
                          NavigationService().navigateToPlaylist(pl),
                    ),
                    );
                  },
                ),
        );
      },
    );
  }
}
