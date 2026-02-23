import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/navigation_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Artists page built from PageTemplate and MusicCard grid.
class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.artists.isEmpty) appState.loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Selector<AppState, List<Artist>>(
      selector: (_, appState) => appState.artists,
      builder: (context, artists, child) {
        final sorted = List<Artist>.from(artists)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return PageTemplate(
          title: l10n.artists,
          child: sorted.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 64, color: DesktopTheme.textMuted),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.noArtistsFound,
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
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final artist = sorted[index];
                    final appState = context.read<AppState>();
                    final imageUrl = artist.imageUrl != null
                        ? appState.getImageUrl(artist.imageUrl!)
                        : null;
                    return KeyedSubtree(
                      key: ValueKey(artist.id),
                      child: MusicCard(
                      title: artist.name,
                      subtitle: l10n.artist,
                      imageUrl: imageUrl,
                      size: 180,
                      placeholderIcon: Icons.person_rounded,
                      onTap: () =>
                          NavigationService().navigateToArtist(artist),
                    ),
                    );
                  },
                ),
        );
      },
    );
  }
}
