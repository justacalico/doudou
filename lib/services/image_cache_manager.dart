import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class ImageCacheManager {
  static const String key = 'doudouImageCache';
  
  static CacheManager? _instance;
  
  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7), // Keep images for 7 days
        maxNrOfCacheObjects: 1000, // Cache up to 1000 images
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }
  
  // Preload images for better performance
  static Future<void> preloadImage(String url) async {
    try {
      await instance.downloadFile(url);
    } catch (e) {
      // Ignore preload errors
    }
  }
  
  // Clear all cached images
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
  
  // Get cache size (simplified version)
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = await instance.store.retrieveFileInfos();
      
      int totalSize = 0;
      for (final fileInfo in files) {
        final file = File(fileInfo.file.path);
        if (await file.exists()) {
          final stat = await file.stat();
          totalSize += stat.size.round();
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
