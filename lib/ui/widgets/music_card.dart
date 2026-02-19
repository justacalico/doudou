import 'package:flutter/material.dart';

import '../theme.dart';
import 'universal_image.dart';

/// Card for horizontal scrolls: artwork + title + subtitle. 12px radius, no shadow.
class MusicCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double size;
  final IconData? placeholderIcon;

  const MusicCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.size = 180,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: AspectRatio(
                aspectRatio: 1,
                child: UniversalImage(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  placeholder: Icon(
                    placeholderIcon ?? Icons.music_note_rounded,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
