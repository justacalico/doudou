import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
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
  
  // Get cache size
  static Future<int> getCacheSize() async {
    final cacheDir = await getTemporaryDirectory();
    final cacheFolder = p.join(cacheDir.path, key);
    
    try {
      final directory = await instance.store.fileDir;
      int size = 0;
      
      await for (final file in directory.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          size += stat.size;
        }
      }
      
      return size;
    } catch (e) {
      return 0;
    }
  }
}
