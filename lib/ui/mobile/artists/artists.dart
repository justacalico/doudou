import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../partials/player/mini_player.dart';
import '../widgets/cached_image_widget.dart';
import 'details/artist_detail.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Builder(
              builder: (context) {
                if (appState.isLoading && appState.artists.isEmpty) {
                  return const Center(
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    ),
                  );
                }

                if (appState.artists.isEmpty) {
                  return Container(
                    color: const Color(0xFF000000), // Pure black for OLED
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.person_2,
                            size: 80,
                            color: Color(0xFF333333),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.noArtistsFound,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              l10n.artistsWillAppear,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8E8E93),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  color: const Color(
                    0xFF000000,
                  ), // Pure black background for OLED
                  child: Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(
                            onRefresh: () => appState.loadLibraryData(),
                          ),
                          // Header section
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title section
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF32D74B,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF32D74B,
                                            ).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.person_2_fill,
                                          color: Color(0xFF32D74B),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.artists,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFFFFFFF),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.artistsCount(
                                                appState.artists.length,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final artist = appState.artists[index];
                              return ArtistCard(artist: artist);
                            }, childCount: appState.artists.length),
                          ),
                          // Add bottom padding for mini player
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MiniPlayer(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class ArtistCard extends StatelessWidget {
  final Artist artist;

  const ArtistCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C1C1E), width: 1),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1C1C1E),
            border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
          ),
          child: ArtistImageWidget(
            imageUrl: artist.imageUrl != null
                ? appState.getImageUrl(
                    artist.imageUrl!,
                    width: 112,
                    height: 112,
                  )
                : null,
            size: 56,
            isCircular: true,
          ),
        ),
        title: Text(
          artist.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF), // Pure white text
            fontSize: 16,
            height: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
          ),
          child: const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: Color(0xFF8E8E93),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ArtistDetailScreen(artist: artist),
            ),
          );
        },
      ),
    );
  }
}
