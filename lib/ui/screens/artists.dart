import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final artists = List<Artist>.from(appState.artists)
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return PageTemplate(
            title: l10n.artists,
            actions: [
              TextButton.icon(
                onPressed: () => appState.loadLibraryData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
            child: artists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline_rounded, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          l10n.noArtistsFound,
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
                    itemCount: artists.length,
                    itemBuilder: (context, i) {
                      final artist = artists[i];
                      final imageUrl = artist.imageUrl != null ? appState.getImageUrl(artist.imageUrl!) : null;
                      return MusicCard(
                        title: artist.name,
                        subtitle: l10n.artist,
                        imageUrl: imageUrl,
                        size: 180,
                        placeholderIcon: Icons.person_rounded,
                        onTap: () => NavigationService().navigateToArtist(artist),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
