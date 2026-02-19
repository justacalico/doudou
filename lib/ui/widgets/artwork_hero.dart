import 'package:flutter/material.dart';

import 'universal_image.dart';

/// Full-bleed artwork. No borders, no shadows. Used in now playing and collection detail header.
class ArtworkHero extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double height;
  final BoxFit fit;

  const ArtworkHero({
    super.key,
    this.imageUrl,
    this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ClipRect(
        child: UniversalImage(
          imageUrl: imageUrl,
          width: width ?? double.infinity,
          height: height,
          fit: fit,
        ),
      ),
    );
  }
}
