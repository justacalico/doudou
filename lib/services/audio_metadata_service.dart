import 'dart:io';
import 'dart:typed_data';

// Conditionally import audiotags only on supported platforms
import 'package:audiotags/audiotags.dart' as audiotags;

/// Wrapper service for audio metadata reading.
/// This provides a platform-safe way to read audio tags, since the audiotags
/// package (which uses flutter_rust_bridge) has issues on iOS builds.
class AudioMetadataService {
  static final AudioMetadataService _instance = AudioMetadataService._internal();
  factory AudioMetadataService() => _instance;
  AudioMetadataService._internal();

  /// Returns true if audio metadata reading is supported on this platform.
  /// iOS is currently not supported due to flutter_rust_bridge build issues.
  bool get isSupported => !Platform.isIOS;

  /// Read audio tags from a file.
  /// Returns null on iOS or if reading fails.
  Future<AudioMetadata?> readMetadata(String filePath) async {
    if (!isSupported) {
      return null;
    }

    try {
      final tag = await audiotags.AudioTags.read(filePath);
      if (tag == null) return null;

      return AudioMetadata(
        title: tag.title,
        trackArtist: tag.trackArtist,
        albumArtist: tag.albumArtist,
        album: tag.album,
        genre: tag.genre,
        year: tag.year,
        trackNumber: tag.trackNumber,
        trackTotal: tag.trackTotal,
        discNumber: tag.discNumber,
        discTotal: tag.discTotal,
        duration: tag.duration,
        pictures: tag.pictures
            .map((p) => AudioPicture(
                  bytes: Uint8List.fromList(p.bytes),
                  mimeType: _convertMimeType(p.mimeType),
                ))
            .toList(),
      );
    } catch (e) {
      // Failed to read tags
      return null;
    }
  }

  /// Convert audiotags MimeType to our simplified enum
  AudioPictureMimeType? _convertMimeType(audiotags.MimeType? mimeType) {
    if (mimeType == null) return null;
    switch (mimeType) {
      case audiotags.MimeType.png:
        return AudioPictureMimeType.png;
      case audiotags.MimeType.gif:
        return AudioPictureMimeType.gif;
      case audiotags.MimeType.bmp:
        return AudioPictureMimeType.bmp;
      case audiotags.MimeType.tiff:
        return AudioPictureMimeType.tiff;
      case audiotags.MimeType.jpeg:
        return AudioPictureMimeType.jpeg;
    }
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
