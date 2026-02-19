import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Artwork loading with cache and placeholder. No borders/shadows.
class UniversalImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholderOrError(context, placeholder ?? _defaultPlaceholder());
    }
    final url = imageUrl!;
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, _) => _placeholderOrError(context, placeholder ?? _defaultPlaceholder()),
        errorWidget: (_, _, _) => _placeholderOrError(context, errorWidget ?? _defaultPlaceholder()),
      );
    }
    return _placeholderOrError(context, errorWidget ?? _defaultPlaceholder());
  }

  Widget _placeholderOrError(BuildContext context, Widget child) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.surface,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _defaultPlaceholder() {
    return Icon(
      Icons.music_note_rounded,
      size: (width != null && height != null) ? (width! < height! ? width! * 0.4 : height! * 0.4) : 48,
      color: AppTheme.textMuted,
    );
  }
}
