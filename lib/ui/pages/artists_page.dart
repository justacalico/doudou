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
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final artists = appState.artists;
        final isYt = appState.isYoutubeMusic;
        final sorted = List<Artist>.from(
          artists,
        )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return PageTemplate(
          title: l10n.artists,
          child: sorted.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 64,
                        color: DesktopTheme.textMuted,
                      ),
                      const SizedBox(height: DesktopTheme.spacingMd),
                      Text(
                        l10n.noArtistsFound,
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
                    final artist = sorted[index];
                    final appState = context.read<AppState>();
                    final imageUrl = artist.imageUrl != null
                        ? appState.getImageUrl(artist.imageUrl!)
                        : null;
                    final isFollowed = appState.isArtistFollowed(artist);
                    return KeyedSubtree(
                      key: ValueKey(artist.id),
                      child: Stack(
                        children: [
                          MusicCard(
                            title: artist.name,
                            subtitle: l10n.artist,
                            imageUrl: imageUrl,
                            size: 180,
                            placeholderIcon: Icons.person_rounded,
                            onTap: () =>
                                NavigationService().navigateToArtist(artist),
                          ),
                          if (isYt)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: DesktopTheme.backgroundDeep.withValues(
                                    alpha: 0.78,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: DesktopTheme.glassBorder),
                                ),
                                child: IconButton(
                                  iconSize: 18,
                                  splashRadius: 18,
                                  tooltip: isFollowed
                                      ? l10n.removeFromFavorites
                                      : l10n.followArtist,
                                  onPressed: () =>
                                      appState.toggleArtistFollow(artist),
                                  icon: Icon(
                                    isFollowed
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFollowed ? Colors.redAccent : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
