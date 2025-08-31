import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_manager.dart';

class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: ImageCacheManager.instance,
      placeholder: (context, url) => placeholder ?? Container(
        width: width,
        height: height,
        color: const Color(0xFF1C1C1E),
        child: const Center(
          child: CupertinoActivityIndicator(
            color: CupertinoColors.systemGrey,
          ),
        ),
      ),
      errorWidget: (context, url, error) => errorWidget ?? Container(
        width: width,
        height: height,
        color: const Color(0xFF1C1C1E),
        child: const Icon(
          CupertinoIcons.photo,
          color: CupertinoColors.systemGrey2,
          size: 32,
        ),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

// Convenience widgets for common use cases
class AlbumArtwork extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const AlbumArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Icon(
          CupertinoIcons.music_albums,
          color: CupertinoColors.systemGrey2,
          size: size * 0.4,
        ),
      ),
    );
  }
}

class ArtistImage extends StatelessWidget {
  final String imageUrl;
  final double size;

  const ArtistImage({
    super.key,
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2), // Circular for artists
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.person,
          color: CupertinoColors.systemGrey2,
          size: size * 0.4,
        ),
      ),
    );
  }
}
