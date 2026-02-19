import 'package:flutter/cupertino.dart';
import 'package:doudou/ui/widgets/cached_image.dart';

/// Thin wrapper around [CachedImage] with a default [placeholderColor] (0xFF2C2C2E) for queue/overlay UIs.
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
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
      placeholderColor: placeholderColor ?? const Color(0xFF2C2C2E),
    );
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
