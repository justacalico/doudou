import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
  
  // Get approximate cache size
  static Future<int> getCacheSize() async {
    try {
      // This is an approximation since we can't easily access internal cache store
      return 0; // Return 0 for now, can be implemented if needed
    } catch (e) {
      return 0;
    }
  }
}
