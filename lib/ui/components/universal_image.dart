import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doudou/services/image_cache_manager.dart';

/// Helper to check if a URL is a local file path
bool isLocalFilePath(String url) {
  return url.startsWith('file://') || url.startsWith('/');
}

/// Helper to get the actual file path from a URL
String getFilePath(String url) {
  if (url.startsWith('file:///')) {
    // Handle Windows paths like file:///C:/path
    final path = url.substring(8);
    if (path.length >= 2 && path[1] == ':') {
      // Windows path with drive letter
      return path;
    }
    // Unix path - add leading slash back
    return '/$path';
  }
  if (url.startsWith('file://')) {
    return url.substring(7);
  }
  return url;
}

/// Universal image widget that handles both network and local file URLs
/// Works on all platforms (Windows, macOS, Linux, mobile, web)
class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, String, DownloadProgress)? progressIndicatorBuilder;
  final Widget Function(BuildContext, String, Object)? errorBuilder;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.progressIndicatorBuilder,
    this.errorBuilder,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocalFilePath(imageUrl)) {
      return _buildLocalImage();
    } else {
      return _buildNetworkImage();
    }
  }

  Widget _buildLocalImage() {
    final filePath = getFilePath(imageUrl);
    final file = File(filePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildPlaceholder();
        }

        if (snapshot.data == true) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? _buildErrorWidget();
            },
          );
        }

        return errorWidget ?? _buildErrorWidget();
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: ImageCacheManager.instance,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      progressIndicatorBuilder: progressIndicatorBuilder,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        Icons.music_note,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
}

/// Smart image widget that automatically builds the appropriate image
/// based on whether it's a local file or network URL
Widget buildSmartImage({
  required String? imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function()? errorBuilder,
}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return errorBuilder?.call() ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF2C2C2E),
          child: const Icon(
            Icons.music_note,
            color: Colors.grey,
            size: 32,
          ),
        );
  }

  if (isLocalFilePath(imageUrl)) {
    final filePath = getFilePath(imageUrl);
    return Image.file(
      File(filePath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) =>
          errorBuilder?.call() ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFF2C2C2E),
            child: const Icon(
              Icons.music_note,
              color: Colors.grey,
              size: 32,
            ),
          ),
    );
  }

  return Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) =>
        errorBuilder?.call() ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF2C2C2E),
          child: const Icon(
            Icons.music_note,
            color: Colors.grey,
            size: 32,
          ),
        ),
  );
}
