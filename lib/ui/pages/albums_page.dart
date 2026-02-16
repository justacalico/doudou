import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/UI/desktop/services/navigation_service.dart';

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
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty) appState.loadLibraryData();
    });
  }

  List<Album> _filtered(AppState appState) {
    var list = List<Album>.from(appState.albums);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
              a.name.toLowerCase().contains(q) ||
              (a.artistName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = _filtered(appState);
        return PageTemplate(
          title: l10n.albums,
          actions: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: DesktopTheme.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DesktopTheme.spacingMd),
            DesktopGlassButton(
              onPressed: () => appState.loadLibraryData(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.refresh),
                ],
              ),
            ),
          ],
          child: albums.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.album_outlined,
                          size: 64, color: DesktopTheme.textMuted),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.noAlbumsFound,
                        style: TextStyle(
                            fontSize: 16, color: DesktopTheme.textSecondary),
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
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final imageUrl = album.imageUrl != null
                        ? appState.getImageUrl(album.imageUrl!)
                        : null;
                    return MusicCard(
                      title: album.name,
                      subtitle: album.artistName ?? l10n.unknownArtist,
                      imageUrl: imageUrl,
                      size: 180,
                      onTap: () => NavigationService().navigateToAlbum(album),
                    );
                  },
                ),
        );
      },
    );
  }
}
