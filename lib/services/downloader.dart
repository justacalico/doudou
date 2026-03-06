import 'dart:async';
import '/l10n/app_localizations.dart';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../ui/screens/Album/album_screen_controller.dart';
import '../ui/screens/Playlist/playlist_screen_controller.dart';
import '/services/stream_service.dart';
import '../ui/widgets/snackbar.dart';
import '/services/permission_service.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '/utils/helper.dart';
import '/models/media_Item_builder.dart';
import '../ui/screens/Library/library_controller.dart';
import '/services/backend/backend_factory.dart';
import 'music_service.dart';
//import '../models/thumbnail.dart' as th;

class Downloader extends GetxService {
  final _dio = Dio();
  MediaItem? currentSong;
  RxMap<String, List<MediaItem>> playlistQueue =
      <String, List<MediaItem>>{}.obs;
  final currentPlaylistId = "".obs;
  final songDownloadingProgress = 0.obs;
  final playlistDownloadingProgress = 0.obs;
  final isJobRunning = false.obs;

  RxList<MediaItem> songQueue = <MediaItem>[].obs;

  Future<bool> checkPermissionNDir() async {
    final settingsScreenController = Get.find<SettingsScreenController>();

    if (!settingsScreenController.isCurrentPathsupportDownDir &&
        !await PermissionService.getExtStoragePermission()) {
      return false;
    }

    final dirPath =
        Get.find<SettingsScreenController>().downloadLocationPath.string;
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return true;
  }

  Future<void> downloadPlaylist(
      String playlistId, List<MediaItem> songList) async {
    if (!(await checkPermissionNDir())) return;

    // for toggle between downloading request & cancelling
    if (playlistQueue.containsKey(playlistId)) {
      songQueue.removeWhere((element) => songList.contains(element));
      playlistQueue.remove(playlistId);
      return;
    }

    playlistQueue[playlistId] = songList;
    songQueue.addAll(songList);

    if (isJobRunning.isFalse) {
      await triggerDownloadingJob();
    }
  }

  Future<void> download(MediaItem? song, {List<MediaItem>? songList}) async {
    if (!(await checkPermissionNDir())) return;
    if (songList != null) {
      songQueue.addAll(songList);
    } else {
      songQueue.add(song!);
    }
    if (isJobRunning.isFalse) {
      await triggerDownloadingJob();
    }
  }

  Future<void> triggerDownloadingJob() async {
    //check if playlist download in queue => download playlistsongs else download from general songs queue
    if (playlistQueue.isNotEmpty) {
      isJobRunning.value = true;
      for (String playlistId in playlistQueue.keys.toList()) {
        //checked in case download cancel request
        if (playlistQueue.containsKey(playlistId)) {
          currentPlaylistId.value = playlistId;
          await downloadSongList((playlistQueue[playlistId]!).toList(),
              isPlaylist: true);
          if (Get.isRegistered<PlaylistScreenController>(
                  tag: Key(playlistId).hashCode.toString()) &&
              playlistQueue.containsKey(playlistId)) {
            Get.find<PlaylistScreenController>(
                    tag: Key(playlistId).hashCode.toString())
                .isDownloaded
                .value = true;
          }
          // in case of album
          else if (Get.isRegistered<AlbumScreenController>(
                  tag: Key(playlistId).hashCode.toString()) &&
              playlistQueue.containsKey(playlistId)) {
            Get.find<AlbumScreenController>(
                    tag: Key(playlistId).hashCode.toString())
                .isDownloaded
                .value = true;
          }
          playlistQueue.remove(playlistId);
        }
        currentPlaylistId.value = "";
        playlistDownloadingProgress.value = 0;
      }
    } else {
      isJobRunning.value = true;
      await downloadSongList(songQueue.toList());
    }

    if (songQueue.isNotEmpty) {
      triggerDownloadingJob();
    } else {
      isJobRunning.value = false;
      currentSong = null;
    }
  }

  Future<void> downloadSongList(List<MediaItem> jobSongList,
      {bool isPlaylist = false}) async {
    for (MediaItem song in jobSongList) {
      // intrrupt downloading task in case of playlist download cancel request
      if (isPlaylist && !playlistQueue.containsKey(currentPlaylistId.value)) {
        currentPlaylistId.value = "";
        playlistDownloadingProgress.value = 0;
        return;
      }

      if (!Hive.box("SongDownloads").containsKey(song.id)) {
        currentSong = song;
        songDownloadingProgress.value = 0;
        await writeFileStream(song);
      }
      songQueue.remove(song);
      //for playlist downloading counter update
      if (isPlaylist) {
        playlistDownloadingProgress.value = jobSongList.indexOf(song) + 1;
      }
    }
  }

  Future<void> writeFileStream(MediaItem song) async {
    final settingsScreenController = Get.find<SettingsScreenController>();
    final downloadingFormat = settingsScreenController.downloadingFormat.string;
    final backendType = song.extras?['backendType']?.toString();
    final isNonYouTube = backendType == 'jellyfin' ||
        backendType == 'subsonic' ||
        backendType == 'plex';
    Audio? requiredAudioStream;
    if (!isNonYouTube) {
      final playerResponse = await StreamProvider.fetch(song.id);
      if (!playerResponse.playable) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
            Get.context!,
            playerResponse.statusMSG == "networkError"
                ? AppLocalizations.of(Get.context!)!.networkError
                : playerResponse.statusMSG,
            size: SnackBarSize.BIG,
            duration: const Duration(seconds: 2),
            top: !GetPlatform.isDesktop));
        printINFO("Requested song is not downloadable. You may try again");
        return;
      }

      requiredAudioStream = downloadingFormat == "opus"
          ? playerResponse.highestBitrateOpusAudio
          : playerResponse.highestBitrateMp4aAudio;
      requiredAudioStream ??= playerResponse.highestQualityAudio;
    } else {
      String? streamUrl = song.extras?['url']?.toString();
      if (streamUrl == null || streamUrl.isEmpty) {
        final rawServerId = song.extras?['serverId'];
        int? serverId;
        if (rawServerId is int) {
          serverId = rawServerId;
        } else if (rawServerId is String) {
          serverId = int.tryParse(rawServerId);
        }
        final servers = settingsScreenController.servers;
        if (serverId != null) {
          for (final server in servers) {
            if (server.id == serverId) {
              streamUrl = await createBackend(server).getStreamUrl(song.id);
              break;
            }
          }
        }
        streamUrl ??=
            await settingsScreenController.currentBackend.getStreamUrl(song.id);
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
            Get.context!, AppLocalizations.of(Get.context!)!.downloadError2,
            size: SnackBarSize.BIG,
            duration: const Duration(seconds: 2),
            top: !GetPlatform.isDesktop));
        printINFO("No backend stream URL available for download");
        return;
      }
      final ext = _suggestedExtensionForBackend(backendType, streamUrl);
      final codec = (ext == 'opus' || ext == 'ogg' || ext == 'webm')
          ? Codec.opus
          : Codec.mp4a;
      requiredAudioStream = Audio(
        itag: 0,
        audioCodec: codec,
        bitrate: 0,
        duration: song.duration?.inMilliseconds ?? 0,
        loudnessDb: 0,
        url: streamUrl,
        size: 0,
      );
    }

    if (requiredAudioStream == null) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.downloadError2,
          size: SnackBarSize.BIG,
          duration: const Duration(seconds: 2),
          top: !GetPlatform.isDesktop));
      return;
    }

    final dirPath = settingsScreenController.downloadLocationPath.string;
    final actualDownformat = isNonYouTube
        ? _suggestedExtensionForBackend(backendType, requiredAudioStream.url)
        : (requiredAudioStream.audioCodec.name.contains("mp") ? "m4a" : "opus");
    final RegExp invalidChar =
        RegExp(r'Container.|\/|\\|\"|\<|\>|\*|\?|\:|\!|\[|\]|\¡|\||\%');
    final songTitle = "${song.title.trim()} (${song.artist?.trim()})"
        .replaceAll(invalidChar, "");
    final normalizedExt = actualDownformat.isEmpty ? "m4a" : actualDownformat;
    String filePath = "$dirPath/$songTitle.$normalizedExt";
    printINFO("Downloading filePath: $filePath");
    final totalBytes = requiredAudioStream.size;

    dynamic response;
    try {
      response = await _dio.download(requiredAudioStream.url, filePath,
          options: (!isNonYouTube && totalBytes > 0)
              ? Options(headers: {"Range": 'bytes=0-$totalBytes'})
              : null, onReceiveProgress: (count, total) {
        if (total <= 0) return;
        songDownloadingProgress.value = ((count / total) * 100).toInt();
      });
    } catch (_) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.downloadError3,
          size: SnackBarSize.BIG,
          duration: const Duration(seconds: 2),
          top: !GetPlatform.isDesktop));
      printINFO(
          "Downloading failed due to network/stream error! Please try again");
      return;
    }
    final statusCode = response?.statusCode;
    if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.downloadError3,
          size: SnackBarSize.BIG,
          duration: const Duration(seconds: 2),
          top: !GetPlatform.isDesktop));
      printINFO("Downloading failed with status code: $statusCode");
      return;
    }
    final downloadedFile = File(filePath);
    if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.downloadError3,
          size: SnackBarSize.BIG,
          duration: const Duration(seconds: 2),
          top: !GetPlatform.isDesktop));
      printINFO("Downloading failed due to empty file output");
      return;
    }

    String? year;
    try {
      if (song.extras?['year'] != null) {
        year = song.extras?['year'];
      } else {
        if (song.album != null) {
          final musicServ = Get.find<MusicServices>();
          year = await musicServ.getSongYear(song.id);
        }
      }
    } catch (_) {}

    // Save Thumbnail
    try {
      final thumbnailPath =
          "${settingsScreenController.supportDirPath}/thumbnails/${song.id}.png";
      await _dio.downloadUri(song.artUri!, thumbnailPath);
      // ignore: empty_catches
    } catch (e) {}

    song.extras?['url'] = filePath;
    final songJson = MediaItemBuilder.toJson(song);
    final streamInfoJson = requiredAudioStream.toJson();
    streamInfoJson['url'] = filePath;
    // [playbility status, info map]
    songJson["streamInfo"] = [true, streamInfoJson];

    Hive.box("SongDownloads").put(song.id, songJson);
    Get.find<LibrarySongsController>().librarySongsList.add(song);
    printINFO("Downloaded successfully");

    final trackDetails = (song.extras?['trackDetails'])?.split("/");
    final int? trackNumber = int.tryParse(trackDetails?[0] ?? "");
    final int? totalTracks = int.tryParse(trackDetails?[1] ?? "");

    try {
      if (isNonYouTube || !_isTaggableExtension(normalizedExt)) {
        return;
      }

      /// Reverted -- Removed AudioTags as using this package, app is flagged as TROJ_GEN.R002V01K623 by TrendMicro-HouseCall
      final imageUrl = song.artUri!.toString();
      Tag tag = Tag(
          title: song.title,
          trackArtist: song.artist,
          album: song.album,
          year: int.tryParse(year ?? ""),
          trackNumber: trackNumber,
          trackTotal: totalTracks,
          albumArtist: song.artist,
          genre: song.genre,
          pictures: [
            Picture(
                bytes: (await NetworkAssetBundle(Uri.parse((imageUrl)))
                        .load(imageUrl))
                    .buffer
                    .asUint8List(),
                mimeType: MimeType.png,
                pictureType: PictureType.coverFront)
          ]);

      await AudioTags.write(filePath, tag);
    } catch (e) {
      printERROR("$e");
    }
  }

  String _fileExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final index = path.lastIndexOf('.');
    if (index == -1 || index == path.length - 1) return '';
    final ext = path.substring(index + 1).toLowerCase();
    if (ext == 'view' || ext == 'php' || ext == 'asp' || ext == 'aspx') {
      return '';
    }
    return ext;
  }

  String _suggestedExtensionForBackend(String? backendType, String url) {
    final ext = _fileExtensionFromUrl(url);
    if (ext.isNotEmpty) return ext;
    if (backendType == 'subsonic') return 'mp3';
    if (backendType == 'plex') return 'm4a';
    if (backendType == 'jellyfin') return 'm4a';
    return 'm4a';
  }

  bool _isTaggableExtension(String ext) {
    return ext == 'mp3' || ext == 'm4a' || ext == 'opus' || ext == 'ogg';
  }
}
