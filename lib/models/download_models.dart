enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
  paused,
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
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      errorMessage: json['errorMessage'],
    );
  }
}

class DownloadedTrack {
  final String trackId;
  final String filePath;
  final String? imagePath;
  final DateTime downloadedAt;
  final int fileSize;

  DownloadedTrack({
    required this.trackId,
    required this.filePath,
    this.imagePath,
    required this.downloadedAt,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'filePath': filePath,
      'imagePath': imagePath,
      'downloadedAt': downloadedAt.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) {
    return DownloadedTrack(
      trackId: json['trackId'],
      filePath: json['filePath'],
      imagePath: json['imagePath'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
      fileSize: json['fileSize'],
    );
  }
}
