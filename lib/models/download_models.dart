enum DownloadStatus { notDownloaded, downloading, downloaded, failed, paused }

/// Minimal track info stored with downloaded album metadata (for showing all tracks in an album).
class MinimalTrackInfo {
  final String id;
  final String name;
  final String? artistName;
  final String? albumName;
  final int? duration;
  final int? trackNumber;

  MinimalTrackInfo({
    required this.id,
    required this.name,
    this.artistName,
    this.albumName,
    this.duration,
    this.trackNumber,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artistName': artistName,
        'albumName': albumName,
        'duration': duration,
        'trackNumber': trackNumber,
      };

  factory MinimalTrackInfo.fromJson(Map<String, dynamic> json) =>
      MinimalTrackInfo(
        id: json['id'],
        name: json['name'],
        artistName: json['artistName'],
        albumName: json['albumName'],
        duration: json['duration'],
        trackNumber: json['trackNumber'],
      );
}

/// Album metadata stored when at least one track from that album is downloaded.
class DownloadedAlbumMetadata {
  final String albumId;
  final String name;
  final String? artistName;
  final String? imageUrl;
  final String? imagePath;
  final List<MinimalTrackInfo> tracks;

  DownloadedAlbumMetadata({
    required this.albumId,
    required this.name,
    this.artistName,
    this.imageUrl,
    this.imagePath,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'name': name,
        'artistName': artistName,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory DownloadedAlbumMetadata.fromJson(Map<String, dynamic> json) =>
      DownloadedAlbumMetadata(
        albumId: json['albumId'],
        name: json['name'],
        artistName: json['artistName'],
        imageUrl: json['imageUrl'],
        imagePath: json['imagePath'],
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((e) => MinimalTrackInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class DownloadTask {
  final String id;
  final String trackId;
  final String trackName;
  final String? artistName;
  final String? albumName;
  final String? imageUrl;
  final String downloadUrl;
  final String filePath;
  DownloadStatus status;
  double progress;
  int? totalBytes;
  int? downloadedBytes;
  DateTime? startTime;
  DateTime? endTime;
  String? errorMessage;
  final bool isFavorite;

  DownloadTask({
    required this.id,
    required this.trackId,
    required this.trackName,
    this.artistName,
    this.albumName,
    this.imageUrl,
    required this.downloadUrl,
    required this.filePath,
    this.status = DownloadStatus.notDownloaded,
    this.progress = 0.0,
    this.totalBytes,
    this.downloadedBytes,
    this.startTime,
    this.endTime,
    this.errorMessage,
    this.isFavorite = false,
  });

  DownloadTask copyWith({
    String? id,
    String? trackId,
    String? trackName,
    String? artistName,
    String? albumName,
    String? imageUrl,
    String? downloadUrl,
    String? filePath,
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? startTime,
    DateTime? endTime,
    String? errorMessage,
    bool? isFavorite,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      imageUrl: imageUrl ?? this.imageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      errorMessage: errorMessage ?? this.errorMessage,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackId': trackId,
      'trackName': trackName,
      'artistName': artistName,
      'albumName': albumName,
      'imageUrl': imageUrl,
      'downloadUrl': downloadUrl,
      'filePath': filePath,
      'status': status.name,
      'progress': progress,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'errorMessage': errorMessage,
      'isFavorite': isFavorite,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      trackId: json['trackId'],
      trackName: json['trackName'],
      artistName: json['artistName'],
      albumName: json['albumName'],
      imageUrl: json['imageUrl'],
      downloadUrl: json['downloadUrl'],
      filePath: json['filePath'],
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.notDownloaded,
      ),
      progress: json['progress']?.toDouble() ?? 0.0,
      totalBytes: json['totalBytes'],
      downloadedBytes: json['downloadedBytes'],
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      errorMessage: json['errorMessage'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

class DownloadedTrack {
  final String trackId;
  final String filePath;
  final String? imagePath;
  final DateTime downloadedAt;
  final int fileSize;
  final bool isFavorite;

  DownloadedTrack({
    required this.trackId,
    required this.filePath,
    this.imagePath,
    required this.downloadedAt,
    required this.fileSize,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'filePath': filePath,
      'imagePath': imagePath,
      'downloadedAt': downloadedAt.toIso8601String(),
      'fileSize': fileSize,
      'isFavorite': isFavorite,
    };
  }

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) {
    return DownloadedTrack(
      trackId: json['trackId'],
      filePath: json['filePath'],
      imagePath: json['imagePath'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
      fileSize: json['fileSize'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}
