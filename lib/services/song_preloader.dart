import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/helper.dart';

typedef SongBytesDownloader = Future<void> Function(
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

  File _fileFor(String songId) => File('${_dir.path}/$songId.mp3');

  File _partFileFor(String songId) => File('${_dir.path}/$songId.mp3.part');

  /// The fully downloaded file for [songId], or null when it was never
  /// preloaded or the download is still in flight.
  File? completeFileFor(String songId) {
    final file = _fileFor(songId);
    return file.existsSync() && file.lengthSync() > 0 ? file : null;
  }

  /// Queues [url] for download. Local urls and songs that are already
  /// fully downloaded are skipped. Returns the download future so tests
  /// can await it; failures are logged, not thrown.
  Future<void> preload(
    String songId,
    String url, {
    Map<String, String>? headers,
  }) {
    if (!url.startsWith('http') || completeFileFor(songId) != null) {
      return Future<void>.value();
    }
    if (_inFlight.containsKey(songId)) {
      return _inFlight[songId]!;
    }
    final task = _tail.then((_) => _download(songId, url, headers));
    _inFlight[songId] = task;
    _tail = task;
    return task;
  }

  Future<void> _download(
      String songId, String url, Map<String, String>? headers) async {
    final partFile = _partFileFor(songId);
    try {
      await _dir.create(recursive: true);
      await _downloader(Uri.parse(url), partFile, headers);
      if (completeFileFor(songId) != null) {
        return;
      }
      await partFile.rename(_fileFor(songId).path);
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
    if (name.endsWith('.mp3.part')) {
      return name.substring(0, name.length - '.mp3.part'.length);
    }
    if (name.endsWith('.mp3')) {
      return name.substring(0, name.length - '.mp3'.length);
    }
    return null;
  }

  bool get hasPendingDownloads => _inFlight.isNotEmpty;

  static Future<void> _downloadWithDio(
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
    } finally {
      dio.close();
    }
  }
}
