import 'dart:io';

import 'package:archive/archive_io.dart';

/// A `.hmb` backup is a zip of `.hive` box files (plus optional downloaded
/// media and thumbnails, which the server ignores since it only holds data).
class HmbImportResult {
  HmbImportResult({required this.boxes, required this.skipped});

  /// Box names imported from the archive (file name minus `.hive`).
  final List<String> boxes;

  /// Archive members skipped because they were not `.hive` files.
  final List<String> skipped;
}

final RegExp _boxNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-\.]{0,63}$');

bool isValidBoxName(String name) => _boxNamePattern.hasMatch(name);

/// Extracts every `.hive` file in [hmbPath] into [dbDir].
///
/// Existing files are overwritten, which is what an import means. Returns
/// the list of imported box names. Throws [HmbImportException] when the file
/// is missing, not a zip, or contains no `.hive` members.
HmbImportResult importHmbFile(String hmbPath, String dbDir) {
  final file = File(hmbPath);
  if (!file.existsSync()) {
    throw HmbImportException('File not found: $hmbPath');
  }
  final bytes = file.readAsBytesSync();
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw HmbImportException('Not a valid .hmb archive: $hmbPath ($e)');
  }

  final dir = Directory(dbDir)..createSync(recursive: true);
  final imported = <String>[];
  final skipped = <String>[];
  for (final member in archive) {
    if (!member.isFile) continue;
    // Zip members can contain nested paths; only the file name matters.
    final name = member.name.split('/').last.split('\\').last;
    if (!name.endsWith('.hive')) {
      skipped.add(member.name);
      continue;
    }
    final boxName = name.substring(0, name.length - '.hive'.length);
    if (!isValidBoxName(boxName)) {
      skipped.add(member.name);
      continue;
    }
    // Hive opens <name>.hive lowercased, so normalize the file name to what
    // the engine actually looks for.
    File('${dir.path}/${boxName.toLowerCase()}.hive')
        .writeAsBytesSync(member.content as List<int>);
    imported.add(boxName);
  }
  if (imported.isEmpty) {
    throw HmbImportException('No .hive database files inside $hmbPath');
  }
  return HmbImportResult(boxes: imported, skipped: skipped);
}

/// Bundles every `.hive` file under [dbDir] into a `.hmb` zip.
/// Returns the names included, or null when there is nothing to export.
Future<List<String>?> exportHmbFile(String dbDir, String outPath) async {
  final dir = Directory(dbDir);
  if (!dir.existsSync()) return null;
  final hiveFiles = dir
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.hive') &&
          !f.path.split(Platform.pathSeparator).last.startsWith('_'))
      .toList();
  if (hiveFiles.isEmpty) return null;

  final archive = Archive();
  for (final f in hiveFiles) {
    final data = await f.readAsBytes();
    final name = f.path.split(Platform.pathSeparator).last;
    archive.addFile(ArchiveFile(name, data.length, data));
  }
  await File(outPath).writeAsBytes(ZipEncoder().encode(archive)!);
  return hiveFiles
      .map((f) => f.path.split(Platform.pathSeparator).last)
      .toList();
}

class HmbImportException implements Exception {
  HmbImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
