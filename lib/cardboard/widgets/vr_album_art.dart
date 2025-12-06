import 'package:flutter/material.dart';

/// VR Album Art Widget
/// 
/// Displays album artwork in a 3D-like format optimized for VR viewing
class VRAlbumArt extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const VRAlbumArt({
    super.key,
    this.imageUrl,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildPlaceholder();
                },
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Icon(
          Icons.album,
          size: size * 0.4,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}
