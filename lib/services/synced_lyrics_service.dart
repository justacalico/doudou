import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:doudou/utils/helper.dart';
import 'package:hive/hive.dart';

class SyncedLyricsService {
  static Future<Map<String, dynamic>?> getSyncedLyrics(
      MediaItem song, int durInSec) async {
    final lyricsBox = await Hive.openBox("lyrics");
    // check if lyrics available in local database
    if (lyricsBox.containsKey(song.id)) {
      return Map<String, dynamic>.from(await lyricsBox.get(song.id));
    }

    int dur = song.duration?.inSeconds ?? durInSec;
    if (dur < 1 || dur > 3600) dur = 180;
    final url =
        'https://lrclib.net/api/get?artist_name=${song.artist?.replaceAll(" ", "+")}&track_name=${song.title.replaceAll(" ", "+")}&album_name=${song.album?.replaceAll(" ", "+")}&duration=$dur';
    try {
      final response = (await Dio().get(url)).data;
      if (response["syncedLyrics"] != null) {
        printINFO("Synced Available");
        final lyricsData = {
          "synced": response["syncedLyrics"],
          "plainLyrics": response["plainLyrics"]
        };
        await lyricsBox.put(song.id, lyricsData);
        return lyricsData;
      }
    } on DioException catch (e) {
      printERROR(e.response);
    } finally {
      await lyricsBox.close();
    }
    return null;
  }
}
