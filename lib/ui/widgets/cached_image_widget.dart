import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doudou/services/image_cache_manager.dart';

/// Helper to check if a URL is a local file path
bool _isLocalFilePath(String url) {
  return url.startsWith('file://') || url.startsWith('/');
}

/// Helper to get the actual file path from a URL
String _getFilePath(String url) {
  if (url.startsWith('file://')) {
    return url.substring(7); // Remove 'file://' prefix
  }
  return url;
}

class CachedImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (_isLocalFilePath(imageUrl)) {
      final filePath = _getFilePath(imageUrl);
      final file = File(filePath);

      image = FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          // Show placeholder while loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: placeholderColor ?? const Color(0xFF2C2C2E),
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                );
          }
          
          if (snapshot.data == true) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return errorWidget ??
                    Container(
                      width: width,
                      height: height,
                      color: const Color(0xFF2C2C2E),
                      child: const Icon(
                        CupertinoIcons.photo,
                        color: CupertinoColors.systemGrey,
                        size: 32,
                      ),
                    );
              },
            );
          }

          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: const Color(0xFF2C2C2E),
                child: const Icon(
                  CupertinoIcons.photo,
                  color: CupertinoColors.systemGrey,
                  size: 32,
                ),
              );
        },
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        cacheManager: ImageCacheManager.instance,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: placeholderColor ?? const Color(0xFF2C2C2E),
              child: const Center(
                child: CupertinoActivityIndicator(
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFF2C2C2E),
              child: const Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.systemGrey,
                size: 32,
              ),
            ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

// Specialized widgets for different content types
class AlbumArtWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const AlbumArtWidget({
    super.key,
    required this.imageUrl,
    this.size = 200,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: borderRadius,
        ),
        child: Icon(
          CupertinoIcons.music_albums,
          color: CupertinoColors.systemGrey,
          size: size * 0.4,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CachedImageWidget(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover, // Crop and scale to fill the entire container
          errorWidget: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: borderRadius,
            ),
            child: Icon(
              CupertinoIcons.music_albums,
              color: CupertinoColors.systemGrey,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool isCircular;

  const ArtistImageWidget({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCircular
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(8);

    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: borderRadius,
        ),
        child: Icon(
          CupertinoIcons.person,
          color: CupertinoColors.systemGrey,
          size: size * 0.5,
        ),
      );
    }

    return CachedImageWidget(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: borderRadius,
        ),
        child: Icon(
          CupertinoIcons.person,
          color: CupertinoColors.systemGrey,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class PlaylistImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const PlaylistImageWidget({
    super.key,
    required this.imageUrl,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);

    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: borderRadius,
        ),
        child: Icon(
          CupertinoIcons.music_note_list,
          color: CupertinoColors.systemGrey,
          size: size * 0.4,
        ),
      );
    }

    return CachedImageWidget(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: borderRadius,
        ),
        child: Icon(
          CupertinoIcons.music_note_list,
          color: CupertinoColors.systemGrey,
          size: size * 0.4,
        ),
      ),
    );
  }
}
