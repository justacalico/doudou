import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/artist.dart';
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

  static const double _narrowBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsScreenController>();
    final isYouTubeServer =
        settings.activeServer?.type == ServerType.youtubeMusic;
    return Obx(() {
      if (!controller.isArtistContentFetced.isTrue) return const SizedBox.shrink();
      final artist = controller.artist_;
      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < _narrowBreakpoint;
          if (isNarrow) {
            return _NarrowArtistHeader(
              controller: controller,
              artist: artist,
              isYouTubeServer: isYouTubeServer,
              theme: theme,
            );
          }
          return _WideArtistHeader(
            controller: controller,
            artist: artist,
            isYouTubeServer: isYouTubeServer,
            theme: theme,
          );
        },
      );
    });
  }
}

class _NarrowArtistHeader extends StatelessWidget {
  const _NarrowArtistHeader({
    required this.controller,
    required this.artist,
    required this.isYouTubeServer,
    required this.theme,
  });

  final ArtistScreenController controller;
  final Artist artist;
  final bool isYouTubeServer;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          _AvatarWithBookmark(
            controller: controller,
            artist: artist,
            isYouTubeServer: isYouTubeServer,
            size: 168,
            theme: theme,
          ),
          const SizedBox(height: 18),
          Text(
            artist.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          _ArtistStats(controller: controller, center: true),
          const SizedBox(height: 18),
          _ArtistActionRow(
            controller: controller,
            isYouTubeServer: isYouTubeServer,
            center: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WideArtistHeader extends StatelessWidget {
  const _WideArtistHeader({
    required this.controller,
    required this.artist,
    required this.isYouTubeServer,
    required this.theme,
  });

  final ArtistScreenController controller;
  final Artist artist;
  final bool isYouTubeServer;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AvatarWithBookmark(
            controller: controller,
            artist: artist,
            isYouTubeServer: isYouTubeServer,
            size: 156,
            theme: theme,
          ),
          const SizedBox(width: 24),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                _ArtistStats(controller: controller, center: false),
                const SizedBox(height: 16),
                _ArtistActionRow(
                  controller: controller,
                  isYouTubeServer: isYouTubeServer,
                  center: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarWithBookmark extends StatelessWidget {
  const _AvatarWithBookmark({
    required this.controller,
    required this.artist,
    required this.isYouTubeServer,
    required this.size,
    required this.theme,
  });

  final ArtistScreenController controller;
  final Artist artist;
  final bool isYouTubeServer;
  final double size;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ImageWidget(size: size, artist: artist),
        ),
        if (isYouTubeServer)
          Positioned(
            bottom: 4,
            right: 4,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _toggleLibrary(context),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: LibraryBookmarkIcon(
                    isBookmarked: controller.isAddedToLibrary.isTrue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
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

class _ArtistStats extends StatelessWidget {
  const _ArtistStats({required this.controller, required this.center});

  final ArtistScreenController controller;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final count = controller.artistSongCount;
      final duration = controller.artistTotalDurationFormatted;
      if (count == 0 && duration.isEmpty) return const SizedBox(height: 4);
      final parts = <String>[];
      if (count > 0) parts.add('$count ${context.l10n.songsCount}');
      if (duration.isNotEmpty) parts.add(duration);
      if (parts.isEmpty) return const SizedBox(height: 4);
      return Text(
        parts.join(' · '),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}

class _ArtistActionRow extends StatelessWidget {
  const _ArtistActionRow({
    required this.controller,
    required this.isYouTubeServer,
    required this.center,
  });

  final ArtistScreenController controller;
  final bool isYouTubeServer;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () => _playAll(context),
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 22),
          label: Text(context.l10n.playAll),
        ),
        OutlinedButton.icon(
          onPressed: () => _shuffle(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: const Icon(Icons.shuffle_rounded, size: 20),
          label: Text(context.l10n.shuffle),
        ),
        PopupMenuButton<String>(
          tooltip: context.l10n.more,
          icon: Icon(
            Icons.more_horiz,
            color: theme.textTheme.titleMedium?.color ?? theme.iconTheme.color,
          ),
          onSelected: (value) {
            if (value == 'about') _showAbout(context);
            if (value == 'radio') _startRadio(context);
            if (value == 'library') _toggleLibrary(context);
          },
          itemBuilder: (context) {
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
              if (isYouTubeServer)
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
    final settings = Get.find<SettingsScreenController>();
    if (settings.activeServer?.type != ServerType.youtubeMusic) return;

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
