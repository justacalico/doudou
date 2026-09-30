import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/helper.dart';
import 'utils.dart';

typedef SongBytesDownloader = FutureOr<String?> Function(
  Uri uri,
  File target,
  Map<String, String>? headers,
);

/// Downloads the audio bytes of upcoming queue items so they keep playing
/// when connectivity drops mid-playback. Files are streamed to a `.part`
/// file and renamed on completion, so an interrupted download is never
/// mistaken for a playable file. Downloads run one at a time to avoid
/// competing with the stream that is currently playing.
class SongPreloader {
  SongPreloader({
    required Directory directory,
    SongBytesDownloader? downloader,
  })  : _dir = directory,
        _downloader = downloader ?? _downloadWithDio;

  final Directory _dir;
  final SongBytesDownloader _downloader;
  final Map<String, Future<void>> _inFlight = {};
  Future<void> _tail = Future<void>.value();

  File _partFileFor(String songId) => File('${_dir.path}/$songId.part');

  /// The fully downloaded file for [songId], or null when it was never
  /// preloaded or the download is still in flight.
  File? completeFileFor(String songId) {
    final file = cachedAudioFile(_dir, songId);
    return file != null && file.lengthSync() > 0 ? file : null;
  }

  /// Queues [url] for download. Local urls and songs that are already
  /// fully downloaded are skipped. [codec] is the resolved stream codec;
  /// it decides the saved file extension, which iOS relies on to pick a
  /// decoder. Returns the download future so tests can await it; failures
  /// are logged, not thrown.
  Future<void> preload(
    String songId,
    String url, {
    Map<String, String>? headers,
    String? codec,
  }) {
    if (!url.startsWith('http') || completeFileFor(songId) != null) {
      return Future<void>.value();
    }
    if (_inFlight.containsKey(songId)) {
      return _inFlight[songId]!;
    }
    final task = _tail.then((_) => _download(songId, url, headers, codec));
    _inFlight[songId] = task;
    _tail = task;
    return task;
  }

  Future<void> _download(String songId, String url,
      Map<String, String>? headers, String? codec) async {
    final partFile = _partFileFor(songId);
    try {
      await _dir.create(recursive: true);
      final contentType = await _downloader(Uri.parse(url), partFile, headers);
      if (completeFileFor(songId) != null) {
        return;
      }
      final ext =
          audioExtensionForMime(contentType) ?? audioExtensionForCodec(codec);
      await partFile.rename('${_dir.path}/$songId.$ext');
    } catch (e) {
      if (partFile.existsSync()) {
        unawaited(partFile.delete().catchError((_) => partFile));
      }
      printWarning('Song preload failed for $songId: $e');
    } finally {
      _inFlight.remove(songId);
    }
  }

  /// Deletes preloaded files for songs that fell outside the keep window,
  /// so the directory stays bounded to the tracks around the current one.
  /// Songs with a download still in flight are kept.
  void retainOnly(Set<String> songIds) {
    if (!_dir.existsSync()) return;
    for (final entity in _dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final id = _songIdForFileName(name);
      if (id == null || songIds.contains(id) || _inFlight.containsKey(id)) {
        continue;
      }
      unawaited(entity.delete().catchError((_) => entity));
    }
  }

  String? _songIdForFileName(String name) {
    if (name.endsWith('.part')) {
      return name.substring(0, name.length - '.part'.length);
    }
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : null;
  }

  bool get hasPendingDownloads => _inFlight.isNotEmpty;

  static Future<String?> _downloadWithDio(
      Uri uri, File target, Map<String, String>? headers) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 1),
    ));
    try {
      final response = await dio.get<ResponseBody>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );
      final sink = target.openWrite();
      try {
        await sink.addStream(response.data!.stream);
      } finally {
        await sink.close();
      }
      return response.headers.value('content-type');
    } finally {
      dio.close();
    }
  }
}
