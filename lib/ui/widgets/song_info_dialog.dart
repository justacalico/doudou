import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/ui/widgets/common_dialog_widget.dart';
import '/utils/server_storage.dart';

class SongInfoDialog extends StatelessWidget {
  final MediaItem song;
  const SongInfoDialog({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    Map<dynamic, dynamic> streamInfo = _getStreamInfo(song.id);
    return CommonDialog(
      child: SizedBox(
        height: Get.mediaQuery.size.height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(context.l10n.songInfo,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(),
            Expanded(
                child: ListView(
              children: [
                InfoItem(title: context.l10n.id, value: song.id),
                InfoItem(title: context.l10n.title, value: song.title),
                if (song.album != null && song.album!.isNotEmpty)
                  InfoItem(title: context.l10n.album, value: song.album!),
                if (song.artist != null && song.artist!.isNotEmpty)
                  InfoItem(title: context.l10n.artists, value: song.artist!),
                if (streamInfo["approxDurationMs"] != null ||
                    song.duration != null)
                  InfoItem(
                      title: context.l10n.duration,
                      value:
                          "${streamInfo["approxDurationMs"] ?? song.duration?.inMilliseconds} ms"),
                if (streamInfo["audioCodec"] != null)
                  InfoItem(
                      title: context.l10n.audioCodec,
                      value: streamInfo["audioCodec"]),
                if (streamInfo["bitrate"] != null)
                  InfoItem(
                      title: context.l10n.bitrate,
                      value: "${streamInfo["bitrate"]}"),
                if (streamInfo["loudnessDb"] != null)
                  InfoItem(
                      title: context.l10n.loudnessDb,
                      value: "${streamInfo["loudnessDb"]}"),
              ],
            )),
            const Divider(),
            SizedBox(
              height: 50,
              child: Align(
                alignment: Alignment.center,
                child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 25),
                      child: Text(context.l10n.close),
                    )),
              ),
            )
          ],
        ),
      ),
    );
  }

  Map<dynamic, dynamic> _getStreamInfo(String id) {
    Map<dynamic, dynamic> tempstreamInfo;
    final nullVal = {
      "audioCodec": null,
      "bitrate": null,
      "loudnessDb": null,
      "approxDurationMs": null
    };
    if (Hive.box(songDownloadsBoxName(currentServerId())).containsKey(id)) {
      final song = Hive.box(songDownloadsBoxName(currentServerId())).get(id);

      tempstreamInfo =
          song["streamInfo"] == null ? nullVal : song["streamInfo"][1];
    } else {
      final dbStreamData = Hive.box(songsUrlCacheBoxName(currentServerId())).get(id);
      tempstreamInfo = dbStreamData != null &&
              dbStreamData.runtimeType.toString().contains("Map")
          ? dbStreamData[Hive.box('AppPrefs').get('streamingQuality') == 0
              ? 'lowQualityAudio'
              : "highQualityAudio"]
          : nullVal;
    }
    return tempstreamInfo;
  }
}

class InfoItem extends StatelessWidget {
  final String title;
  final String value;
  const InfoItem({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
          ),
          TextSelectionTheme(
            data: Theme.of(context).textSelectionTheme,
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
        ],
      ),
    );
  }
}
