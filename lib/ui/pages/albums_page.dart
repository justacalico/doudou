import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Albums page built from reusable PageTemplate and MusicCard grid.
class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) appState.loadLibraryData();
    });
  }

  List<Album> _sortedFromList(List<Album> list) {
    final result = List<Album>.from(list);
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = appState.isYoutubeMusic
            ? appState.favoriteAlbums
            : appState.albums;
        final sorted = _sortedFromList(albums);
        return PageTemplate(
          title: l10n.albums,
          child: sorted.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.album_outlined,
                        size: 64,
                        color: DesktopTheme.textMuted,
                      ),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.noAlbumsFound,
                        style: TextStyle(
                          fontSize: 16,
                          color: DesktopTheme.textSecondary,
                        ),
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
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final album = sorted[index];
                    final appState = context.read<AppState>();
                    final imageUrl = album.imageUrl != null
                        ? appState.getImageUrl(album.imageUrl!)
                        : null;
                    return KeyedSubtree(
                      key: ValueKey(album.id),
                      child: MusicCard(
                        title: album.name,
                        subtitle: album.artistName ?? l10n.unknownArtist,
                        imageUrl: imageUrl,
                        size: 180,
                        onTap: () => NavigationService().navigateToAlbum(album),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
