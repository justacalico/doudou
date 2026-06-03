import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/playling_from.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/songinfo_bottom_sheet.dart';

class ArtistSongsTable extends StatelessWidget {
  const ArtistSongsTable({
    super.key,
    required this.items,
    required this.artistName,
    required this.controllerTag,
    this.scrollController,
  });

  final List<dynamic> items;
  final String artistName;
  final String controllerTag;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noSongsInLibrary,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final list = items as List<MediaItem>;
    final theme = Theme.of(context);
    return ListView(
      key: PageStorageKey('artist-songs-table-$artistName-$controllerTag'),
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 200),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text("#", style: theme.textTheme.labelSmall)),
              Expanded(flex: 3, child: Text(context.l10n.title, style: theme.textTheme.labelSmall)),
              SizedBox(width: 64, child: Text(context.l10n.duration, style: theme.textTheme.labelSmall)),
              if (GetPlatform.isDesktop) const SizedBox(width: 40),
            ],
          ),
        ),
        const Divider(height: 1),
        ...list.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final song = entry.value;
          final playerController = Get.find<PlayerController>();
          return InkWell(
            onTap: () {
              playerController.playPlayListSong(
                list,
                entry.key,
                playfrom: PlaylingFrom(type: PlaylingFromType.ARTIST, name: artistName),
              );
            },
            onLongPress: () {
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                isScrollControlled: true,
                context: Get.find<ShellController>().overlayContextOrFallback!,
                barrierColor: Colors.transparent.withAlpha(100),
                builder: (ctx) => SongInfoBottomSheet(song),
              ).whenComplete(() => Get.delete<SongInfoController>());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      "$i",
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.artist != null || song.album != null)
                          Text(
                            [song.artist, song.album].whereType<String>().join(' • '),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      song.extras?['length']?.toString() ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (GetPlatform.isDesktop)
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 500),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          isScrollControlled: true,
                          context: Get.find<ShellController>().overlayContextOrFallback!,
                          barrierColor: Colors.transparent.withAlpha(100),
                          builder: (ctx) => SongInfoBottomSheet(song),
                        ).whenComplete(() => Get.delete<SongInfoController>());
                      },
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
