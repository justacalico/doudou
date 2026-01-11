import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Reusable cached image widget with loading and error states
class CachedArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  const CachedArtwork({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = CupertinoIcons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.surface(context),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: fit,
                placeholder: (context, url) => _buildPlaceholder(context),
                errorWidget: (context, url, error) => _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.elevated(context),
      child: Icon(
        placeholderIcon,
        size: size * 0.4,
        color: AppTheme.textSecondary(context),
      ),
    );
  }
}
