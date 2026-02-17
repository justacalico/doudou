import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_models.dart';
import '../models/jellyfin_models.dart';
import 'media_service_manager.dart';

class DownloadService extends ChangeNotifier {
  final MediaServiceManager _mediaServiceManager;
  final Map<String, DownloadTask> _downloadTasks = {};
  final Map<String, DownloadedTrack> _downloadedTracks = {};
  final Map<String, DownloadedAlbumMetadata> _downloadedAlbumMetadata = {};
  final List<String> _downloadQueue = [];
  bool _isDownloading = false;
  final int _maxConcurrentDownloads = 3;
  int _activeDownloads = 0;
  
  // Throttle progress updates to avoid excessive UI rebuilds
  DateTime? _lastProgressNotification;
  static const Duration _progressThrottleDuration = Duration(milliseconds: 200);
  Timer? _progressThrottleTimer;

  DownloadService(this._mediaServiceManager) {
    _loadDownloadData();
  }
  
  @override
  void dispose() {
    _progressThrottleTimer?.cancel();
    super.dispose();
  }

  // Getters
  List<DownloadTask> get downloadTasks => _downloadTasks.values.toList();
  Map<String, DownloadedTrack> get downloadedTracks =>
      Map.unmodifiable(_downloadedTracks);
  bool get isDownloading => _isDownloading;
  int get activeDownloads => _activeDownloads;
  int get queueLength => _downloadQueue.length;

  // Check if a track is downloaded
  bool isTrackDownloaded(String trackId) {
    return _downloadedTracks.containsKey(trackId);
  }

  // Get download status for a track
  DownloadStatus getDownloadStatus(String trackId) {
    if (_downloadedTracks.containsKey(trackId)) {
      return DownloadStatus.downloaded;
    }
    final task = _downloadTasks.values.firstWhere(
      (task) => task.trackId == trackId,
      orElse: () => DownloadTask(
        id: '',
        trackId: '',
        trackName: '',
        downloadUrl: '',
        filePath: '',
      ),
    );
    return task.id.isEmpty ? DownloadStatus.notDownloaded : task.status;
  }

  // Get download progress for a track
  double getDownloadProgress(String trackId) {
    final task = _downloadTasks.values.firstWhere(
      (task) => task.trackId == trackId,
      orElse: () => DownloadTask(
        id: '',
        trackId: '',
        trackName: '',
        downloadUrl: '',
        filePath: '',
      ),
    );
    return task.id.isEmpty ? 0.0 : task.progress;
  }

  // Get local file path for a downloaded track
  String? getLocalFilePath(String trackId) {
    return _downloadedTracks[trackId]?.filePath;
  }

  // Get favorite status for a downloaded track
  bool? getDownloadedTrackFavoriteStatus(String trackId) {
    return _downloadedTracks[trackId]?.isFavorite;
  }

  /// Albums that have at least one downloaded track (metadata stored for showing all tracks).
  List<DownloadedAlbumMetadata> get downloadedAlbums {
    return _downloadedAlbumMetadata.values
        .where((album) =>
            album.tracks.any((t) => _downloadedTracks.containsKey(t.id)))
        .toList();
  }

  DownloadedAlbumMetadata? getAlbumMetadata(String albumId) =>
      _downloadedAlbumMetadata[albumId];

  // Download a track
  Future<void> downloadTrack(Track track) async {
    if (isTrackDownloaded(track.id)) {
      return; // Already downloaded
    }

    // Check if already downloading (but allow retry for failed/paused downloads)
    final existingTask = _downloadTasks[track.id];
    if (existingTask != null &&
        existingTask.status == DownloadStatus.downloading) {
      return; // Already downloading
    }

    // If there's a failed or paused task, remove it first and clean up
    if (existingTask != null &&
        (existingTask.status == DownloadStatus.failed ||
            existingTask.status == DownloadStatus.paused)) {
      // Clean up any partial file from the previous attempt
      final oldFile = File(existingTask.filePath);
      if (await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (e) {
          // Failed to clean up partial file
        }
      }

      // Remove the old task completely so we can create a fresh one
      _downloadTasks.remove(track.id);
      _downloadQueue.remove(track.id);

      // Save state after cleanup (non-blocking)
      _saveDownloadData().catchError((e) {
        debugPrint('Error saving download data: $e');
      });
      notifyListeners();
    }

    try {
      // Get download URL from the current media service (supports Jellyfin, Subsonic/Navidrome, Plex, etc.)
      final downloadUrl = _mediaServiceManager.getDirectStreamUrl(track.id);

      if (downloadUrl.isEmpty) {
        throw Exception('Could not get download URL for track. Make sure you are connected to the server.');
      }

      // Create downloads directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create file path
      final fileName = '${track.id}.mp3'; // Jellyfin usually serves as MP3
      final filePath = '${downloadsDir.path}/$fileName';

      // Create download task
      final task = DownloadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        imageUrl: track.imageUrl,
        downloadUrl: downloadUrl,
        filePath: filePath,
        status: DownloadStatus.downloading,
        startTime: DateTime.now(),
        isFavorite: track.isFavorite,
      );

      _downloadTasks[track.id] = task;
      _downloadQueue.add(track.id);

      // Ensure we have album metadata for this track's album (for showing all tracks in Downloads)
      if (track.albumId != null && track.albumId!.isNotEmpty) {
        await _ensureAlbumMetadata(track);
      }

      notifyListeners();
      // Save asynchronously without blocking download start
      _saveDownloadData().catchError((e) {
        debugPrint('Error saving download data: $e');
      });

      // Start downloading if not at max concurrent downloads
      _processDownloadQueue();
    } catch (e) {
      debugPrint('Error starting download for ${track.name}: $e');
    }
  }

  Future<void> _ensureAlbumMetadata(Track track) async {
    final albumId = track.albumId!;
    if (_downloadedAlbumMetadata.containsKey(albumId)) return;
    try {
      final tracks = await _mediaServiceManager.getTracks(parentId: albumId);
      final minimal = tracks
          .map((t) => MinimalTrackInfo(
                id: t.id,
                name: t.name,
                artistName: t.artistName,
                albumName: t.albumName,
                duration: t.duration,
                trackNumber: t.trackNumber,
              ))
          .toList();
      _downloadedAlbumMetadata[albumId] = DownloadedAlbumMetadata(
        albumId: albumId,
        name: track.albumName ?? track.name,
        artistName: track.artistName,
        imageUrl: track.imageUrl,
        tracks: minimal,
      );
      // Save asynchronously without blocking
      _saveDownloadData().catchError((e) {
        debugPrint('Error saving download data: $e');
      });
    } catch (e) {
      debugPrint('Could not fetch album metadata for ${track.albumId}: $e');
    }
  }

  // Process download queue
  Future<void> _processDownloadQueue() async {
    if (_activeDownloads >= _maxConcurrentDownloads || _downloadQueue.isEmpty) {
      return;
    }

    _isDownloading = true;
    _activeDownloads++;

    final trackId = _downloadQueue.removeAt(0);
    final task = _downloadTasks[trackId];

    if (task == null) {
      _activeDownloads--;
      _checkDownloadComplete();
      return;
    }

    // Update task status to downloading and notify UI immediately
    _downloadTasks[trackId] = task.copyWith(
      status: DownloadStatus.downloading,
      startTime: DateTime.now(),
    );
    notifyListeners();

    try {
      await _downloadFile(task);
    } catch (e) {
      debugPrint('Download failed for ${task.trackName}: $e');

      // Update task status to failed
      _downloadTasks[trackId] = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );

      // Notify listeners immediately when a download fails
      notifyListeners();
    }

    _activeDownloads--;
    // Save asynchronously without blocking queue processing
    _saveDownloadData().catchError((e) {
      debugPrint('Error saving download data: $e');
    });
    notifyListeners();

    // Continue processing queue
    _processDownloadQueue();
    _checkDownloadComplete();
  }

  // Download individual file
  Future<void> _downloadFile(DownloadTask task) async {
    final file = File(task.filePath);

    try {
      final request = http.Request('GET', Uri.parse(task.downloadUrl));

      // Add authentication headers (for Jellyfin/Plex; Subsonic has auth in URL)
      final headers = await _mediaServiceManager.getAuthHeaders();
      request.headers.addAll(headers);

      final response = await request.send();

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int downloadedBytes = 0;

        // Update task with total size
        _downloadTasks[task.trackId] = task.copyWith(
          totalBytes: totalBytes,
          downloadedBytes: 0,
        );

        final sink = file.openWrite();

        // Create a completer to handle the async completion properly
        final completer = Completer<void>();

        response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            final progress = totalBytes > 0
                ? downloadedBytes / totalBytes
                : 0.0;

            // Update progress (always update the task, but throttle UI notifications)
            _downloadTasks[task.trackId] = task.copyWith(
              progress: progress,
              downloadedBytes: downloadedBytes,
            );

            // Throttle progress notifications to avoid excessive UI rebuilds
            _throttledNotifyListeners();
          },
          onDone: () async {
            try {
              await sink.close();

              // Download completed successfully
              final fileSize = await file.length();

              final downloadedTrack = DownloadedTrack(
                trackId: task.trackId,
                filePath: task.filePath,
                downloadedAt: DateTime.now(),
                fileSize: fileSize,
                isFavorite: task.isFavorite,
              );

              _downloadedTracks[task.trackId] = downloadedTrack;

              // Remove completed task from download tasks and queue since it's now in downloadedTracks
              _downloadTasks.remove(task.trackId);
              _downloadQueue.remove(task.trackId);

              // Also download album artwork if available
              if (task.imageUrl != null) {
                try {
                  await _downloadAlbumArt(task);
                } catch (e) {
                  debugPrint('Failed to download album art: $e');
                }
              }

              notifyListeners();
              // Save asynchronously without blocking
              _saveDownloadData().catchError((e) {
                debugPrint('Error saving download data: $e');
              });

              completer.complete();
            } catch (e) {
              debugPrint(
                'Error in download completion for ${task.trackName}: $e',
              );
              // Mark as failed if completion processing fails
              _downloadTasks[task.trackId] = task.copyWith(
                status: DownloadStatus.failed,
                errorMessage: 'Failed to complete download: $e',
                endTime: DateTime.now(),
              );
              notifyListeners();
              // Save asynchronously without blocking
              _saveDownloadData().catchError((e) {
                debugPrint('Error saving download data: $e');
              });
              completer.completeError(e);
            }
          },
          onError: (error) async {
            try {
              await sink.close();

              // Delete partial file
              if (await file.exists()) {
                await file.delete();
              }

              completer.completeError(error);
            } catch (e) {
              completer.completeError(e);
            }
          },
        );

        // Wait for the download to complete
        await completer.future;
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to download');
      }
    } catch (e) {
      // Delete partial file if it exists
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  // Download album artwork
  Future<void> _downloadAlbumArt(DownloadTask task) async {
    if (task.imageUrl == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/downloads/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final imageFileName = '${task.trackId}_image.jpg';
      final imagePath = '${imagesDir.path}/$imageFileName';
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        return; // Already downloaded
      }

      final imageUrl = _mediaServiceManager.getImageUrl(
        task.imageUrl!,
        width: 300,
        height: 300,
      );
      final headers = await _mediaServiceManager.getAuthHeaders();

      final response = await http.get(Uri.parse(imageUrl), headers: headers);

      if (response.statusCode == 200) {
        await imageFile.writeAsBytes(response.bodyBytes);

        // Update downloaded track with image path
        final downloadedTrack = _downloadedTracks[task.trackId];
        if (downloadedTrack != null) {
          _downloadedTracks[task.trackId] = DownloadedTrack(
            trackId: downloadedTrack.trackId,
            filePath: downloadedTrack.filePath,
            imagePath: imagePath,
            downloadedAt: downloadedTrack.downloadedAt,
            fileSize: downloadedTrack.fileSize,
            isFavorite: downloadedTrack.isFavorite,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to download album art for ${task.trackName}: $e');
    }
  }

  // Cancel a download
  Future<void> cancelDownload(String trackId) async {
    final task = _downloadTasks[trackId];
    if (task == null) return;

    // Remove from queue if pending
    _downloadQueue.remove(trackId);

    // Update status to paused/cancelled
    _downloadTasks[trackId] = task.copyWith(
      status: DownloadStatus.paused,
      endTime: DateTime.now(),
    );

    // Delete partial file if it exists
    final file = File(task.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    notifyListeners();
    // Save asynchronously without blocking
    _saveDownloadData().catchError((e) {
      debugPrint('Error saving download data: $e');
    });
  }

  // Delete a downloaded track
  Future<void> deleteDownload(String trackId) async {
    final downloadedTrack = _downloadedTracks[trackId];
    if (downloadedTrack == null) return;

    try {
      // Delete audio file
      final audioFile = File(downloadedTrack.filePath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      // Delete image file if it exists
      if (downloadedTrack.imagePath != null) {
        final imageFile = File(downloadedTrack.imagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }

      // Remove from maps
      _downloadedTracks.remove(trackId);
      _downloadTasks.remove(trackId);

      notifyListeners();
      // Save asynchronously without blocking
      _saveDownloadData().catchError((e) {
        debugPrint('Error saving download data: $e');
      });
    } catch (e) {
      debugPrint('Error deleting download for $trackId: $e');
    }
  }

  // Get total downloaded size
  Future<int> getTotalDownloadedSize() async {
    int totalSize = 0;
    for (final track in _downloadedTracks.values) {
      totalSize += track.fileSize;

      // Add image size if exists
      if (track.imagePath != null) {
        final imageFile = File(track.imagePath!);
        if (await imageFile.exists()) {
          final imageStat = await imageFile.stat();
          totalSize += imageStat.size;
        }
      }
    }
    return totalSize;
  }

  // Clear all downloads
  Future<void> clearAllDownloads() async {
    for (final trackId in _downloadedTracks.keys.toList()) {
      await deleteDownload(trackId);
    }
  }

  // Throttled notifyListeners for progress updates
  void _throttledNotifyListeners() {
    final now = DateTime.now();
    if (_lastProgressNotification == null ||
        now.difference(_lastProgressNotification!) >= _progressThrottleDuration) {
      _lastProgressNotification = now;
      notifyListeners();
    } else {
      // Schedule a delayed notification if one isn't already scheduled
      _progressThrottleTimer?.cancel();
      _progressThrottleTimer = Timer(_progressThrottleDuration, () {
        _lastProgressNotification = DateTime.now();
        notifyListeners();
      });
    }
  }

  // Check if downloading is complete
  void _checkDownloadComplete() {
    if (_activeDownloads == 0 && _downloadQueue.isEmpty) {
      _isDownloading = false;
      _progressThrottleTimer?.cancel();
      notifyListeners();
    }
  }

  // Save download data to persistent storage (runs asynchronously, non-blocking)
  Future<void> _saveDownloadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save download tasks (only save incomplete tasks)
      final incompleteTasks = _downloadTasks.values
          .where((task) => task.status != DownloadStatus.downloaded)
          .toList();
      final tasksJson = incompleteTasks.map((task) => task.toJson()).toList();
      await prefs.setString('download_tasks', jsonEncode(tasksJson));

      // Save downloaded tracks
      final tracksJson = _downloadedTracks.values
          .map((track) => track.toJson())
          .toList();
      await prefs.setString('downloaded_tracks', jsonEncode(tracksJson));

      // Save downloaded album metadata
      final albumsJson = _downloadedAlbumMetadata.values
          .map((a) => a.toJson())
          .toList();
      await prefs.setString('downloaded_album_metadata', jsonEncode(albumsJson));
    } catch (e) {
      debugPrint('Error saving download data: $e');
    }
  }

  // Load download data from persistent storage
  Future<void> _loadDownloadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load download tasks
      final tasksJsonString = prefs.getString('download_tasks');
      if (tasksJsonString != null) {
        final tasksList = jsonDecode(tasksJsonString) as List;
        for (final taskJson in tasksList) {
          final task = DownloadTask.fromJson(taskJson);

          // Reset any downloading tasks to failed (app was closed during download)
          // Skip any completed tasks that might be in storage
          if (task.status == DownloadStatus.downloaded) {
            continue;
          } else if (task.status == DownloadStatus.downloading) {
            // Reset any downloading tasks to failed (app was closed during download)
            final failedTask = task.copyWith(
              status: DownloadStatus.failed,
              errorMessage: 'Download interrupted',
              endTime: DateTime.now(),
            );
            _downloadTasks[task.trackId] = failedTask;
          } else {
            _downloadTasks[task.trackId] = task;
          }
        }
      }

      // Load downloaded tracks
      final tracksJsonString = prefs.getString('downloaded_tracks');
      if (tracksJsonString != null) {
        final tracksList = jsonDecode(tracksJsonString) as List;
        for (final trackJson in tracksList) {
          final track = DownloadedTrack.fromJson(trackJson);

          // Verify file still exists
          final file = File(track.filePath);
          if (await file.exists()) {
            _downloadedTracks[track.trackId] = track;
          }
        }
      }

      // Load downloaded album metadata
      final albumsJsonString = prefs.getString('downloaded_album_metadata');
      if (albumsJsonString != null) {
        final albumsList = jsonDecode(albumsJsonString) as List;
        for (final albumJson in albumsList) {
          final meta = DownloadedAlbumMetadata.fromJson(albumJson);
          _downloadedAlbumMetadata[meta.albumId] = meta;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading download data: $e');
    }
  }
}
