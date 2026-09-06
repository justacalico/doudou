import 'package:doudou/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafLocation', () {
    test('returns true for content URIs', () {
      expect(
        ExportService.isSafLocation(
            'content://com.android.externalstorage.documents/tree/primary%3AMusic'),
        isTrue,
      );
    });

    test('returns false for filesystem paths', () {
      expect(ExportService.isSafLocation('/storage/emulated/0/Music'), isFalse);
      expect(ExportService.isSafLocation('/data/user/0/app/Exports'), isFalse);
    });

    test('returns false for null and empty', () {
      expect(ExportService.isSafLocation(null), isFalse);
      expect(ExportService.isSafLocation(''), isFalse);
    });
  });

  group('hasWriteAccess', () {
    test('returns true for filesystem paths', () async {
      expect(await ExportService.hasWriteAccess('/some/dir'), isTrue);
    });

    test('returns true for null and empty', () async {
      expect(await ExportService.hasWriteAccess(null), isTrue);
      expect(await ExportService.hasWriteAccess(''), isTrue);
    });

    test('returns true for SAF URIs on non-Android hosts', () async {
      // The persisted-permission check only runs on Android; elsewhere a
      // content URI should not gate the export flow.
      expect(
        await ExportService.hasWriteAccess('content://provider/tree/x'),
        isTrue,
      );
    });
  });

  group('normalizeStoredLocation', () {
    test('keeps SAF tree URIs', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic';
      expect(ExportService.normalizeStoredLocation(uri), uri);
    });

    test('clears legacy filesystem paths', () {
      expect(
          ExportService.normalizeStoredLocation('/storage/emulated/0/Music'),
          '');
      expect(ExportService.normalizeStoredLocation('/app/files/Exports'), '');
    });

    test('clears null and non-string values', () {
      expect(ExportService.normalizeStoredLocation(null), '');
      expect(ExportService.normalizeStoredLocation(42), '');
    });
  });

  group('locationLabel', () {
    test('returns filesystem paths unchanged', () {
      expect(
        ExportService.locationLabel('/home/user/Downloads'),
        '/home/user/Downloads',
      );
    });

    test('extracts the document path from a SAF tree URI', () {
      expect(
        ExportService.locationLabel(
            'content://com.android.externalstorage.documents/tree/primary%3AMusic%2FDoudou'),
        'Music/Doudou',
      );
    });

    test('returns the doc id when it has no path part', () {
      expect(
        ExportService.locationLabel(
            'content://com.android.externalstorage.documents/tree/home%3A'),
        'home:',
      );
    });

    test('returns empty for null and empty input', () {
      expect(ExportService.locationLabel(null), '');
      expect(ExportService.locationLabel(''), '');
    });
  });

  group('exportMimeType', () {
    test('maps audio extensions', () {
      expect(ExportService.exportMimeType('song.m4a'), 'audio/mp4');
      expect(ExportService.exportMimeType('song.opus'), 'audio/ogg');
      expect(ExportService.exportMimeType('song.mp3'), 'audio/mpeg');
    });

    test('maps document extensions', () {
      expect(ExportService.exportMimeType('list.json'), 'application/json');
      expect(ExportService.exportMimeType('list.csv'), 'text/csv');
      expect(ExportService.exportMimeType('backup.hmb'), 'application/zip');
    });

    test('is case-insensitive', () {
      expect(ExportService.exportMimeType('SONG.M4A'), 'audio/mp4');
    });

    test('falls back to octet-stream for unknown or missing extensions', () {
      expect(ExportService.exportMimeType('file.xyz'),
          'application/octet-stream');
      expect(ExportService.exportMimeType('noext'), 'application/octet-stream');
      expect(
          ExportService.exportMimeType('trailing.'), 'application/octet-stream');
    });
  });
}
