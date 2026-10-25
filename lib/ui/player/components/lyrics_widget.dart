import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:get/get.dart';

import '../../screens/Settings/settings_screen_controller.dart';
import '../../widgets/loader.dart';
import 'lyrics_block_highlight_view.dart';
import '../player_controller.dart';

class LyricsWidget extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool onDarkSurface;
  const LyricsWidget(
      {super.key, required this.padding, this.onDarkSurface = false});

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
    final settingsController = Get.find<SettingsScreenController>();
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
                        ? context.l10n.lyricsNotAvailable
                        : playerController.lyrics["plainLyrics"],
                    textAlign: TextAlign.center,
                    style: widget.onDarkSurface
                        ? Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(color: Colors.white)
                        : Theme.of(context).textTheme.titleMedium!,
                  ),
                ),
              ),
            ),
          );
        }

        final lyricsStyle = settingsController.syncedLyricsHighlightStyle.value;
        if (lyricsStyle == SyncedLyricsHighlightStyle.block) {
          return LyricsBlockHighlightView(
            padding: widget.padding, onDarkSurface: widget.onDarkSurface);
        }
        final karaokePadding = widget.padding is EdgeInsets
            ? widget.padding as EdgeInsets
            : const EdgeInsets.only(left: 5, right: 5);

        return LyricsReader(
          padding: karaokePadding,
          lyricUi: playerController.lyricUi,
          playing:
              playerController.buttonState.value == PlayButtonState.playing,
          position:
              playerController.progressBarStatus.value.current.inMilliseconds,
          model: _cachedModel,
          emptyBuilder: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 28,
                  color: widget.onDarkSurface
                      ? Colors.white.withValues(alpha: 0.6)
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.syncedLyricsNotAvailable,
                  style: widget.onDarkSurface
                      ? Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(color: Colors.white)
                      : Theme.of(context).textTheme.titleMedium!,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
