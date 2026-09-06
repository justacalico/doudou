import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '/utils/helper.dart';

/// Helpers for writing exported files to a user-picked destination.
///
/// Scoped storage on Android blocks direct writes to shared directories, so
/// destinations there are Storage Access Framework `content://` tree URIs.
/// On every other platform a destination is a plain filesystem path.
class ExportService {
  static bool isSafLocation(String? location) =>
      location != null && location.startsWith('content://');

  /// Lets the user pick a folder. Returns a SAF tree URI on Android and a
  /// filesystem path elsewhere. Returns null when the picker is cancelled.
  static Future<String?> pickExportFolder({String? dialogTitle}) async {
    if (GetPlatform.isAndroid) {
      final picked = await SafUtil().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      return picked?.uri;
    }
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: dialogTitle ?? 'Select export folder');
    if (dir == null || dir == '/') return null;
    return dir;
  }

  /// Whether a stored SAF tree URI still grants write access. Plain
  /// filesystem paths always report true.
  static Future<bool> hasWriteAccess(String? location) async {
    if (!isSafLocation(location) || !GetPlatform.isAndroid) {
      return true;
    }
    try {
      return await SafUtil().hasPersistedPermission(
        location!,
        checkRead: false,
        checkWrite: true,
      );
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=export.hasWriteAccess] SAF permission check failed for $location: $e\n$st');
      return false;
    }
  }

  /// Copies a local file into [location] (SAF tree URI or filesystem path).
  /// Returns the created file's URI/path.
  static Future<String?> copyToExportLocation(
      String srcPath, String fileName, String location) async {
    if (isSafLocation(location)) {
      final created = await SafStream().pasteLocalFile(
        srcPath,
        location,
        fileName,
        exportMimeType(fileName),
      );
      return created.uri.toString();
    }
    final dest = '$location/$fileName';
    await File(srcPath).copy(dest);
    return dest;
  }

  /// Writes [bytes] into [location] (SAF tree URI or filesystem path).
  /// Returns the created file's URI/path.
  static Future<String?> writeToExportLocation(
      Uint8List bytes, String fileName, String location) async {
    if (isSafLocation(location)) {
      final created = await SafStream().writeFileBytes(
        location,
        fileName,
        exportMimeType(fileName),
        bytes,
      );
      return created.uri.toString();
    }
    final dest = '$location/$fileName';
    await File(dest).writeAsBytes(bytes);
    return dest;
  }

  /// Short human-readable label for a stored export location. SAF tree URIs
  /// are reduced to their document id path (e.g. `Music/Doudou`).
  static String locationLabel(String? location) {
    if (location == null || location.isEmpty) return '';
    if (!isSafLocation(location)) return location;
    final segments = Uri.parse(location).pathSegments;
    if (segments.isEmpty) return location;
    final docId = segments.last;
    final separatorIndex = docId.indexOf(':');
    if (separatorIndex < 0 || separatorIndex == docId.length - 1) {
      return docId;
    }
    return docId.substring(separatorIndex + 1);
  }

  /// Normalizes a stored export location value: SAF URIs survive, anything
  /// else (legacy app dir paths, missing values) becomes empty so the next
  /// export asks the user to pick a folder.
  static String normalizeStoredLocation(dynamic stored) =>
      stored is String && isSafLocation(stored) ? stored : '';

  static String exportMimeType(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return 'application/octet-stream';
    }
    switch (fileName.substring(dotIndex + 1).toLowerCase()) {
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'opus':
      case 'ogg':
        return 'audio/ogg';
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      case 'json':
      case 'jsonl':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      case 'txt':
      case 'log':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'hmb':
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
