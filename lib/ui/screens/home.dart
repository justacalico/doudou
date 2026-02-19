import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../../services/base_service.dart';
import '../layout/navigation_service.dart';
import '../theme.dart';
import '../widgets/horizontal_card_scroll.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';
import '../widgets/section_header.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLibraryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final isYtMusic = appState.mediaServiceManager.currentServerType == ServerType.youtubeMusic;
          final ytSections = appState.youtubeMusicHomeSections;

          if (appState.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 3),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Loading your music...',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return PageTemplate(
            title: l10n.navHome,
            subtitle: _greeting(),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppTheme.spacingMd),
                  if (isYtMusic && ytSections.isNotEmpty) ...[
                    _ytMusicSearchBar(context),
                    const SizedBox(height: AppTheme.spacingXl),
                    ..._ytMusicSections(context, appState, l10n),
                  ] else ...[
                    _quickAccess(context, appState, l10n),
                    const SizedBox(height: AppTheme.spacingXl),
                    if (appState.mediaServiceManager.currentServerType != ServerType.soundcloud) ...[
                      if (_albumsForHome(appState).isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.recentlyAddedAlbums,
                          subtitle: l10n.yourNewestAdditions,
                          onSeeAllPressed: () => NavigationService().selectPage(3),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _recentAlbumsRow(context, appState, l10n),
                        const SizedBox(height: AppTheme.spacingXl),
                      ],
                      if (appState.recentlyPlayedAlbums.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.continueListening,
                          subtitle: l10n.recentlyPlayedSection,
                          onSeeAllPressed: () => NavigationService().selectPage(3),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _continueListeningRow(context, appState, l10n),
                        const SizedBox(height: AppTheme.spacingXl),
                      ],
                    ],
                    if (appState.artists.isNotEmpty) ...[
                      SectionHeader(
                        title: l10n.yourArtists,
                        subtitle: l10n.browseByArtist,
                        onSeeAllPressed: () => NavigationService().selectPage(4),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      _artistRow(context, appState, l10n),
                      const SizedBox(height: AppTheme.spacingXl),
                    ],
                    if (appState.mediaServiceManager.currentServerType != ServerType.soundcloud &&
                        appState.mediaServiceManager.currentServerType != ServerType.youtubeMusic &&
                        appState.tracks.isNotEmpty) ...[
                      SectionHeader(
                        title: l10n.recentTracks,
                        subtitle: l10n.yourMusicCollection,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      _recentTracks(context, appState, l10n),
                    ],
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _ytMusicSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => NavigationService().selectPage(1),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.textMuted, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 22, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.spacingMd),
            Text(
              'Songs, Playlist, Album or Artist',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _ytMusicSections(BuildContext context, AppState appState, AppLocalizations l10n) {
    final sections = appState.youtubeMusicHomeSections;
    if (sections.isEmpty) return [];
    final list = <Widget>[];
    YTMHomeSection? quickPicks;
    for (final s in sections) {
      if (s.tracks.isNotEmpty) {
        quickPicks = s;
        break;
      }
    }
    if (quickPicks != null && quickPicks.tracks.isNotEmpty) {
      list.add(SectionHeader(title: quickPicks.title.isNotEmpty ? quickPicks.title : 'Quick Picks'));
      list.add(const SizedBox(height: AppTheme.spacingMd));
      list.add(
        HorizontalCardScroll(
          itemCount: quickPicks.tracks.take(10).length,
          itemWidth: 160,
          height: 220,
          itemBuilder: (context, i) {
            final track = quickPicks!.tracks[i];
            final imageUrl = track.imageUrl != null ? appState.getImageUrl(track.imageUrl!) : null;
            return MusicCard(
              title: track.name,
              subtitle: track.artistName ?? '',
              imageUrl: imageUrl,
              size: 160,
              onTap: () => appState.playPlaylist(quickPicks!.tracks, i),
            );
          },
        ),
      );
      list.add(const SizedBox(height: AppTheme.spacingXl));
    }
    for (final section in sections) {
      if (section.playlists.isNotEmpty) {
        list.add(SectionHeader(title: section.title.isNotEmpty ? section.title : 'Playlists'));
        list.add(const SizedBox(height: AppTheme.spacingMd));
        list.add(
          HorizontalCardScroll(
            itemCount: section.playlists.take(10).length,
            itemWidth: 180,
            height: 230,
            itemBuilder: (context, i) {
              final pl = section.playlists[i];
              final imageUrl = pl.imageUrl != null ? appState.getImageUrl(pl.imageUrl!) : null;
              return MusicCard(
                title: pl.name,
                subtitle: '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
                imageUrl: imageUrl,
                size: 180,
                onTap: () => NavigationService().navigateToPlaylist(pl),
              );
            },
          ),
        );
        list.add(const SizedBox(height: AppTheme.spacingXl));
      }
      if (section.albums.isNotEmpty) {
        list.add(SectionHeader(title: section.title.isNotEmpty ? section.title : 'Albums'));
        list.add(const SizedBox(height: AppTheme.spacingMd));
        list.add(
          HorizontalCardScroll(
            itemCount: section.albums.take(10).length,
            itemWidth: 180,
            height: 230,
            itemBuilder: (context, i) {
              final album = section.albums[i];
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
        list.add(const SizedBox(height: AppTheme.spacingXl));
      }
    }
    return list;
  }

  List<Album> _albumsForHome(AppState appState) {
    final st = appState.mediaServiceManager.currentServerType;
    final followBased = st == ServerType.youtubeMusic || st == ServerType.soundcloud;
    if (!followBased) return List<Album>.from(appState.albums);
    final artistNames = appState.artists.map((a) => a.name.toLowerCase()).toSet();
    return appState.albums
        .where((a) =>
            a.artistName != null &&
            artistNames.contains(a.artistName!.toLowerCase()))
        .toList();
  }

  Widget _quickAccess(BuildContext context, AppState appState, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 500;
        final shuffleAll = _QuickCard(
          title: 'Shuffle All',
          subtitle: l10n.countSongs(appState.tracks.length),
          icon: Icons.shuffle_rounded,
          onTap: () => appState.shuffleAllTracks(),
        );
        final shuffleFav = _QuickCard(
          title: 'Shuffle Favorites',
          subtitle: l10n.countSongs(appState.tracks.where((t) => t.isFavorite).length),
          icon: Icons.favorite_rounded,
          onTap: () => appState.shuffleFavoriteTracks(),
        );
        if (narrow) {
          return Column(
            children: [
              shuffleAll,
              const SizedBox(height: AppTheme.spacingMd),
              shuffleFav,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: shuffleAll),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: shuffleFav),
          ],
        );
      },
    );
  }

  Widget _recentAlbumsRow(BuildContext context, AppState appState, AppLocalizations l10n) {
    final albums = _albumsForHome(appState);
    final sorted = List<Album>.from(albums)
      ..sort((a, b) {
        final da = a.dateCreated;
        final db = b.dateCreated;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final list = sorted.take(10).toList();
    return HorizontalCardScroll(
      itemCount: list.length,
      itemWidth: 180,
      height: 230,
      itemBuilder: (context, i) {
        final album = list[i];
        final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
        return MusicCard(
          title: album.name,
          subtitle: album.artistName ?? l10n.unknownArtist,
          imageUrl: imageUrl,
          size: 180,
          onTap: () => NavigationService().navigateToAlbum(album),
        );
      },
    );
  }

  Widget _continueListeningRow(BuildContext context, AppState appState, AppLocalizations l10n) {
    final list = appState.recentlyPlayedAlbums.take(8).toList();
    return HorizontalCardScroll(
      itemCount: list.length,
      itemWidth: 180,
      height: 230,
      itemBuilder: (context, i) {
        final album = list[i];
        final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
        return MusicCard(
          title: album.name,
          subtitle: album.artistName ?? l10n.unknownArtist,
          imageUrl: imageUrl,
          size: 180,
          onTap: () => NavigationService().navigateToAlbum(album),
        );
      },
    );
  }

  Widget _artistRow(BuildContext context, AppState appState, AppLocalizations l10n) {
    final list = appState.artists.take(10).toList();
    return HorizontalCardScroll(
      itemCount: list.length,
      itemWidth: 180,
      height: 230,
      itemBuilder: (context, i) {
        final artist = list[i];
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
    );
  }

  Widget _recentTracks(BuildContext context, AppState appState, AppLocalizations l10n) {
    final list = appState.tracks.take(8).toList();
    return Column(
      children: list
          .map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: TrackTile(
                track: track,
                index: appState.tracks.indexOf(track),
                playlist: appState.tracks,
                showTrackNumber: false,
                showArtwork: true,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
