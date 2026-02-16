import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/UI/desktop/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Library hub: quick links to Albums, Artists, Tracks, Playlists using shared templates.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return PageTemplate(
          title: l10n.navLibrary,
          actions: [
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: l10n.libraryOverview,
                  subtitle: l10n.yourMusicCollection,
                ),
                const SizedBox(height: DesktopTheme.spacingMd),
                Wrap(
                  spacing: DesktopTheme.spacingMd,
                  runSpacing: DesktopTheme.spacingMd,
                  children: [
                    _LibraryTile(
                      icon: Icons.album_rounded,
                      label: l10n.albums,
                      count: appState.albums.length,
                      onTap: () => NavigationService().selectPage(3),
                    ),
                    _LibraryTile(
                      icon: Icons.person_rounded,
                      label: l10n.artists,
                      count: appState.artists.length,
                      onTap: () => NavigationService().selectPage(4),
                    ),
                    _LibraryTile(
                      icon: Icons.music_note_rounded,
                      label: l10n.songs,
                      count: appState.tracks.length,
                      onTap: () => NavigationService().selectPage(5),
                    ),
                    _LibraryTile(
                      icon: Icons.queue_music_rounded,
                      label: l10n.playlists,
                      count: appState.playlists.length,
                      onTap: () => NavigationService().selectPage(6),
                    ),
                  ],
                ),
                if (appState.albums.isNotEmpty) ...[
                  const SizedBox(height: DesktopTheme.spacingXl),
                  SectionHeader(
                    title: l10n.recentlyAddedAlbums,
                    onSeeAllPressed: () => NavigationService().selectPage(3),
                  ),
                  const SizedBox(height: DesktopTheme.spacingMd),
                  SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: appState.albums.take(8).length,
                      itemBuilder: (context, index) {
                        final album = appState.albums[index];
                        final imageUrl = album.imageUrl != null
                            ? appState.getImageUrl(album.imageUrl!)
                            : null;
                        return Padding(
                          padding: EdgeInsets.only(
                              right: index < 7 ? DesktopTheme.spacingMd : 0),
                          child: MusicCard(
                            title: album.name,
                            subtitle: album.artistName ?? l10n.unknownArtist,
                            imageUrl: imageUrl,
                            size: 160,
                            onTap: () =>
                                NavigationService().navigateToAlbum(album),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _LibraryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(DesktopTheme.spacingLg),
          decoration: BoxDecoration(
            color: DesktopTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
            border: Border.all(color: DesktopTheme.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: DesktopTheme.textPrimary),
              const SizedBox(height: DesktopTheme.spacingSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DesktopTheme.textPrimary,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
