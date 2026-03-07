import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/models/album.dart';
import '/models/artist.dart';
import '/models/playling_from.dart';
import '/models/playlist.dart';
import '/ui/constants/doudou_design.dart';
import '/utils/app_l10n.dart';
import '/ui/player/player_controller.dart';
import '/ui/navigator.dart';
import '/ui/widgets/image_widget.dart';

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}

Widget buildTrackRowSection({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<MediaItem> items,
  required String playLabel,
  required PlayerController playerController,
  bool showViewAll = false,
  VoidCallback? onViewAll,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: kDoudouPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kDoudouZinc500,
                  ),
                ),
              ],
            ),
          ),
          if (showViewAll)
            TextButton(
              onPressed: onViewAll ?? () {},
              style: TextButton.styleFrom(
                foregroundColor: kDoudouPurpleLight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.l10n.viewAll.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final track = items[index];
            return Padding(
              padding: EdgeInsets.only(
                right: index < items.length - 1 ? 12 : 0,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.circular(kDoudouRadiusIconBox),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(kDoudouRadiusIconBox),
                  onTap: () {
                    playerController.playPlayListSong(
                      items,
                      index,
                      playfrom: PlaylingFrom(
                        name: playLabel,
                        type: PlaylingFromType.SELECTION,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                      borderRadius:
                          BorderRadius.circular(kDoudouRadiusIconBox),
                    ),
                    child: SizedBox(
                      width: 280,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ImageWidget(
                              song: track,
                              size: 56,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${track.artist ?? context.l10n.unknownArtist} • ${track.album ?? context.l10n.unknownAlbum}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                          color: kDoudouZinc500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget buildPlaylistRowSection({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<Playlist> playlists,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: kDoudouPurple,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: kDoudouZinc500,
          ),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Padding(
              padding: EdgeInsets.only(
                right: index < playlists.length - 1 ? 12 : 0,
              ),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(kDoudouRadiusCard),
                onTap: () {
                  ScreenNavigationSetup.pushContentRoute(
                    ScreenNavigationSetup.playlistScreen,
                    arguments: [playlist, playlist.playlistId],
                  );
                },
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusCard),
                        child: ImageWidget(
                          playlist: playlist,
                          size: 180,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget buildAlbumRowSection({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<Album> albums,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: kDoudouPurple,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: kDoudouZinc500,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final artistName = (album.artists != null &&
                    album.artists!.isNotEmpty &&
                    (album.artists![0]['name'] as String?) != null)
                ? album.artists![0]['name'] as String
                : context.l10n.unknownArtist;
            return Padding(
              padding: EdgeInsets.only(
                right: index < albums.length - 1 ? 12 : 0,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScreenNavigationSetup.pushContentRoute(
                    ScreenNavigationSetup.albumScreen,
                    arguments: (album, album.browseId),
                  );
                },
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusCard),
                        child: ImageWidget(
                          album: album,
                          size: 180,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget buildArtistRowSection({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<Artist> artists,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return Padding(
              padding: EdgeInsets.only(
                right: index < artists.length - 1 ? 12 : 0,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScreenNavigationSetup.pushContentRoute(
                    ScreenNavigationSetup.artistScreen,
                    arguments: [false, artist],
                  );
                },
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImageWidget(
                        artist: artist,
                        size: 180,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget buildFreshPicksSection({
  required BuildContext context,
  required List<MediaItem> items,
  required PlayerController playerController,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.homeFreshPicks,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        context.l10n.yourMusicCollection,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: 12),
      Column(
        children: items
            .map(
              (track) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final index = items.indexOf(track);
                    if (index >= 0) {
                      playerController.playPlayListSong(
                        items,
                        index,
                        playfrom: PlaylingFrom(
                          name: context.l10n.homeFreshPicks,
                          type: PlaylingFromType.SELECTION,
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      ImageWidget(
                        song: track,
                        size: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${track.artist ?? context.l10n.unknownArtist} • ${track.album ?? context.l10n.unknownAlbum}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (track.duration != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(track.duration!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}
