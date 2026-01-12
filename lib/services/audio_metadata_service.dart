import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;

/// Service for reading audio metadata from files.
/// Uses audio_metadata_reader which is a pure Dart package that works on all platforms.
class AudioMetadataService {
  static final AudioMetadataService _instance = AudioMetadataService._internal();
  factory AudioMetadataService() => _instance;
  AudioMetadataService._internal();

  /// Returns true if audio metadata reading is supported on this platform.
  /// Now supported on all platforms since we use pure Dart.
  bool get isSupported => true;

  /// Read audio tags from a file.
  /// Returns null if reading fails.
  Future<AudioMetadata?> readMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final metadata = amr.readMetadata(file, getImage: true);

      return AudioMetadata(
        title: metadata.title,
        trackArtist: metadata.artist,
        albumArtist: metadata.artist, // audio_metadata_reader doesn't have albumArtist, use artist
        album: metadata.album,
        genre: metadata.genres.isNotEmpty ? metadata.genres.first : null,
        year: metadata.year?.year,
        trackNumber: metadata.trackNumber,
        trackTotal: metadata.trackTotal,
        discNumber: metadata.discNumber,
        discTotal: metadata.totalDisc,
        duration: metadata.duration?.inSeconds,
        pictures: metadata.pictures
            .map((p) => AudioPicture(
                  bytes: p.bytes,
                  mimeType: _convertMimeType(p.mimetype),
                ))
            .toList(),
      );
    } catch (e) {
      // Failed to read tags
      return null;
    }
  }

  /// Convert mime type string to our simplified enum
  AudioPictureMimeType? _convertMimeType(String? mimeType) {
    if (mimeType == null) return null;
    final lower = mimeType.toLowerCase();
    if (lower.contains('png')) return AudioPictureMimeType.png;
    if (lower.contains('gif')) return AudioPictureMimeType.gif;
    if (lower.contains('bmp')) return AudioPictureMimeType.bmp;
    if (lower.contains('tiff')) return AudioPictureMimeType.tiff;
    if (lower.contains('jpeg') || lower.contains('jpg')) {
      return AudioPictureMimeType.jpeg;
    }
    return AudioPictureMimeType.jpeg; // Default to jpeg for unknown
  }
}

/// Simplified audio metadata class
class AudioMetadata {
  final String? title;
  final String? trackArtist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final int? duration;
  final List<AudioPicture> pictures;

  AudioMetadata({
    this.title,
    this.trackArtist,
    this.albumArtist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.duration,
    this.pictures = const [],
  });
}

/// Simplified picture class
class AudioPicture {
  final Uint8List bytes;
  final AudioPictureMimeType? mimeType;

  AudioPicture({
    required this.bytes,
    this.mimeType,
  });
}

/// Simplified mime type enum
enum AudioPictureMimeType {
  jpeg,
  png,
  gif,
  bmp,
  tiff,
}

/// Helper extension to get file extension from mime type
extension AudioPictureMimeTypeExtension on AudioPictureMimeType {
  String get extension {
    switch (this) {
      case AudioPictureMimeType.png:
        return '.png';
      case AudioPictureMimeType.gif:
        return '.gif';
      case AudioPictureMimeType.bmp:
        return '.bmp';
      case AudioPictureMimeType.tiff:
        return '.tiff';
      case AudioPictureMimeType.jpeg:
        return '.jpg';
    }
  }
}
