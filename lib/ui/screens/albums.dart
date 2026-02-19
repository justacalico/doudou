import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
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
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              TextButton.icon(
                onPressed: () => appState.loadLibraryData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
            child: albums.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.album_outlined, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          l10n.noAlbumsFound,
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: AppTheme.spacingMd,
                      mainAxisSpacing: AppTheme.spacingMd,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final album = albums[i];
                      final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
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
      ),
    );
  }
}
