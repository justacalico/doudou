import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/playling_from.dart';
import '/ui/player/player_controller.dart';
import '/ui/widgets/image_widget.dart';
import '/ui/widgets/library_bookmark_icon.dart';
import '/ui/widgets/snackbar.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/models/server.dart';
import 'about_artist.dart';
import 'artist_screen_controller.dart';

class ArtistHeader extends StatelessWidget {
  const ArtistHeader({
    super.key,
    required this.controller,
  });

  final ArtistScreenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Obx(() {
        if (!controller.isArtistContentFetced.isTrue) return const SizedBox.shrink();
        final artist = controller.artist_;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: ImageWidget(size: 140, artist: artist),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        final add = controller.isAddedToLibrary.isFalse;
                        controller.addNremoveFromLibrary(add: add).then((value) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(snackbar(
                                context,
                                value
                                    ? add
                                        ? context.l10n.artistBookmarkAddAlert
                                        : context.l10n.artistBookmarkRemoveAlert
                                    : context.l10n.operationFailed,
                                size: SnackBarSize.MEDIUM));
                          }
                        });
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: LibraryBookmarkIcon(
                          isBookmarked: controller.isAddedToLibrary.isTrue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.artistLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() {
                    final count = controller.artistSongCount;
                    final duration = controller.artistTotalDurationFormatted;
                    if (count == 0 && duration.isEmpty) return const SizedBox(height: 8);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          if (count > 0) ...[
                            Flexible(
                              child: Text(
                                '$count ${context.l10n.songsCount}',
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (duration.isNotEmpty) ...[
                              Text(
                                ' · ',
                                style: theme.textTheme.bodySmall,
                              ),
                              Flexible(
                                child: Text(
                                  duration,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ] else if (duration.isNotEmpty)
                            Flexible(
                              child: Text(
                                duration,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.l10n.playAll,
                          onPressed: () => _playAll(context),
                          icon: Icon(
                            Icons.play_circle,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.shuffle,
                          onPressed: () => _shuffle(context),
                          icon: Icon(
                            Icons.shuffle,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: context.l10n.more,
                          icon: Icon(
                            Icons.more_horiz,
                            color: theme.textTheme.titleMedium?.color ??
                                theme.iconTheme.color,
                          ),
                          onSelected: (value) {
                            if (value == 'about') _showAbout(context);
                            if (value == 'radio') _startRadio(context);
                            if (value == 'library') _toggleLibrary(context);
                          },
                          itemBuilder: (context) {
                            final settings =
                                Get.find<SettingsScreenController>();
                            final server = settings.activeServer;
                            final isYouTubeServer =
                                server?.type == ServerType.youtubeMusic;

                            final items = <PopupMenuItem<String>>[
                              if (isYouTubeServer)
                                PopupMenuItem(
                                  value: 'radio',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sensors),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          context.l10n.startRadio,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'library',
                                child: Row(
                                  children: [
                                    Icon(controller.isAddedToLibrary.isTrue
                                        ? Icons.bookmark_remove
                                        : Icons.bookmark_add),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        controller.isAddedToLibrary.isTrue
                                            ? context.l10n.removeFromLib
                                            : context.l10n.addToLibrary,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                            if (AboutArtist.hasDescription(controller)) {
                              items.insert(
                                0,
                                PopupMenuItem(
                                  value: 'about',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          context.l10n.about,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return items;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _playAll(BuildContext context) async {
    await controller.ensureSongsLoaded();
    final songs = controller.sepataredContent['Songs']?['results'];
    if (songs == null || (songs as List).isEmpty) return;
    final list = List<MediaItem>.from(songs);
    Get.find<PlayerController>().playPlayListSong(
      list,
      0,
      playfrom: PlaylingFrom(type: PlaylingFromType.ARTIST, name: controller.artist_.name),
    );
  }

  Future<void> _shuffle(BuildContext context) async {
    await controller.ensureSongsLoaded();
    final songs = controller.sepataredContent['Songs']?['results'];
    if (songs == null || (songs as List).isEmpty) return;
    final list = List<MediaItem>.from(songs)..shuffle();
    Get.find<PlayerController>().playPlayListSong(
      list,
      0,
      playfrom: PlaylingFrom(type: PlaylingFromType.ARTIST, name: controller.artist_.name),
    );
  }

  void _startRadio(BuildContext context) {
    final radioId = controller.artist_.radioId;
    if (radioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          snackbar(context, context.l10n.radioNotAvailable, size: SnackBarSize.BIG));
      return;
    }
    Get.find<PlayerController>().startRadio(null, playlistid: radioId);
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: AboutArtist(
              artistScreenController: controller,
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleLibrary(BuildContext context) {
    final add = controller.isAddedToLibrary.isFalse;
    controller.addNremoveFromLibrary(add: add).then((value) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackbar(
            context,
            value
                ? add
                    ? context.l10n.artistBookmarkAddAlert
                    : context.l10n.artistBookmarkRemoveAlert
                : context.l10n.operationFailed,
            size: SnackBarSize.MEDIUM));
      }
    });
  }
}
