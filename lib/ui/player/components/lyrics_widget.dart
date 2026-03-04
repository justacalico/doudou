import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:get/get.dart';

import '../../widgets/loader.dart';
import '../player_controller.dart';

class LyricsWidget extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  const LyricsWidget({super.key, required this.padding});

  @override
  State<LyricsWidget> createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<LyricsWidget> {
  String _cachedSyncedRaw = '';
  dynamic _cachedModel;

  void _refreshModelIfNeeded(String syncedRaw) {
    if (syncedRaw == _cachedSyncedRaw) return;
    _cachedSyncedRaw = syncedRaw;
    if (syncedRaw.trim().isEmpty) {
      _cachedModel = null;
      return;
    }
    _cachedModel =
        LyricsModelBuilder.create().bindLyricToMain(syncedRaw).getModel();
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    return Obx(
      () {
        if (playerController.isLyricsLoading.isTrue) {
          return const Center(child: LoadingIndicator());
        }

        final syncedRaw = playerController.lyrics['synced']?.toString() ?? '';
        _refreshModelIfNeeded(syncedRaw);

        if (playerController.lyricsMode.toInt() == 1) {
          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: widget.padding,
              child: Obx(
                () => TextSelectionTheme(
                  data: Theme.of(context).textSelectionTheme,
                  child: SelectableText(
                    playerController.lyrics["plainLyrics"] == "NA"
                        ? "lyricsNotAvailable".tr
                        : playerController.lyrics["plainLyrics"],
                    textAlign: TextAlign.center,
                    style: playerController.isDesktopLyricsDialogOpen
                        ? Theme.of(context).textTheme.titleMedium!
                        : Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }

        return IgnorePointer(
          child: LyricsReader(
            padding: const EdgeInsets.only(left: 5, right: 5),
            lyricUi: playerController.lyricUi,
            playing:
                playerController.buttonState.value == PlayButtonState.playing,
            position:
                playerController.progressBarStatus.value.current.inMilliseconds,
            model: _cachedModel,
            emptyBuilder: () => Center(
              child: Text(
                "syncedLyricsNotAvailable".tr,
                style: playerController.isDesktopLyricsDialogOpen
                    ? Theme.of(context).textTheme.titleMedium!
                    : Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
