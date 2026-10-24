import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.root);

  final String root;

  String _dir(String name) {
    final dir = Directory('$root/$name');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() async => _dir('tmp');

  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('documents');

  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');

  @override
  Future<String?> getDownloadsPath() async => _dir('downloads');

  @override
  Future<String?> getLibraryPath() async => _dir('library');

  @override
  Future<String?> getExternalStoragePath() async => _dir('external');

  @override
  Future<List<String>?> getExternalCachePaths() async => [_dir('external_cache')];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      [_dir('external')];
}
