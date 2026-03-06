import 'package:audio_service/audio_service.dart' show MediaItem;
import '/utils/app_l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../../models/playlist.dart';
import '../player/player_controller.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '../shell_controller.dart';
import 'add_to_playlist.dart';
import 'image_widget.dart';
import 'snackbar.dart';
import 'songinfo_bottom_sheet.dart';

class SongListTile extends StatelessWidget with RemoveSongFromPlaylistMixin {
  const SongListTile(
      {super.key,
      this.onTap,
      required this.song,
      this.playlist,
      this.isPlaylistOrAlbum = false,
      this.thumbReplacementWithIndex = false,
      this.isActive = false,
      this.index});
  final Playlist? playlist;
  final MediaItem song;
  final VoidCallback? onTap;
  final bool isPlaylistOrAlbum;
  final bool isActive;

  /// Valid for Album songs
  final bool thumbReplacementWithIndex;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final theme = Theme.of(context);
    
    return Listener(
        onPointerDown: (PointerDownEvent event) {
          if (event.buttons == kSecondaryMouseButton) {
            //show songinfobotomsheet
            showModalBottomSheet(
              constraints: const BoxConstraints(maxWidth: 500),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
              ),
              isScrollControlled: true,
              context: Get.find<ShellController>().overlayContextOrFallback!,
              barrierColor: Colors.transparent.withAlpha(100),
              builder: (context) => SongInfoBottomSheet(
                song,
                playlist: playlist,
              ),
            ).whenComplete(() => Get.delete<SongInfoController>());
          }
        },
        child: Slidable(
          enabled:
              Get.find<SettingsScreenController>().slidableActionEnabled.isTrue,
          startActionPane: ActionPane(motion: const DrawerMotion(), children: [
            SlidableAction(
              onPressed: (context) {
                showDialog(
                  context: context,
                  builder: (context) => AddToPlaylist([song]),
                ).whenComplete(() => Get.delete<AddToPlaylistController>());
              },
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.textTheme.titleMedium!.color,
              icon: Icons.playlist_add,
              //label: 'Add to playlist',
            ),
            if (playlist != null && !playlist!.isCloudPlaylist)
              SlidableAction(
                onPressed: (context) {
                  removeSongFromPlaylist(song, playlist!);
                },
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.textTheme.titleMedium!.color,
                icon: Icons.delete,
                //label: 'delete',
              ),
          ]),
          endActionPane: ActionPane(motion: const DrawerMotion(), children: [
            SlidableAction(
              onPressed: (context) {
                playerController.enqueueSong(song).whenComplete(() {
                  showAppSnackBar(context.l10n.songEnqueueAlert,
                      size: SnackBarSize.MEDIUM);
                });
              },
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.textTheme.titleMedium!.color,
              icon: Icons.merge,
              //label: 'Enqueue',
            ),
            SlidableAction(
              onPressed: (context) {
                playerController.playNext(song);
                showAppSnackBar("${context.l10n.playnextMsg} ${(song).title}",
                    size: SnackBarSize.BIG);
              },
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.textTheme.titleMedium!.color,
              icon: Icons.next_plan_outlined,
              //label: 'Play Next',
            ),
          ]),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isActive 
                  ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1)
                  : null,
            ),
            child: ListTile(
              onTap: onTap,
              onLongPress: () async {
                showModalBottomSheet(
                  constraints: const BoxConstraints(maxWidth: 500),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10.0)),
                  ),
                  isScrollControlled: true,
                  context: Get.find<ShellController>().overlayContextOrFallback!,
                  barrierColor: Colors.transparent.withAlpha(100),
                  builder: (context) => SongInfoBottomSheet(
                    song,
                    playlist: playlist,
                  ),
                ).whenComplete(() => Get.delete<SongInfoController>());
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: thumbReplacementWithIndex
                  ? SizedBox(
                      width: 24,
                      child: Center(
                        child: Text(
                          "$index",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  : ImageWidget(
                      size: 48,
                      song: song,
                    ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isActive ? theme.colorScheme.primary : null,
                ),
              ),
              subtitle: Text(
                "${song.artist}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.equalizer, size: 16, color: theme.colorScheme.primary),
                    ),
                  Text(
                    song.extras!['length'] ?? "",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (GetPlatform.isDesktop)
                    IconButton(
                        splashRadius: 20,
                        onPressed: () {
                          showModalBottomSheet(
                            constraints: const BoxConstraints(maxWidth: 500),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0)),
                            ),
                            isScrollControlled: true,
                            context: Get.find<ShellController>()
                                .overlayContextOrFallback!,
                            barrierColor: Colors.transparent.withAlpha(100),
                            builder: (context) => SongInfoBottomSheet(
                              song,
                              playlist: playlist,
                            ),
                          ).whenComplete(
                              () => Get.delete<SongInfoController>());
                        },
                        icon: const Icon(Icons.more_vert, size: 20))
                ],
              ),
            ),
          ),
        ));
  }
}
