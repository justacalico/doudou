import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'image_cache_manager.dart';

class AlbumArtColorService {
  static final Map<String, Color> _colorCache = <String, Color>{};

  static Future<Color?> getDominantGlowColor(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    final cachedColor = _colorCache[imageUrl];
    if (cachedColor != null) {
      return cachedColor;
    }

    try {
      final bytes = await _loadImageBytes(imageUrl);
      if (bytes == null || bytes.isEmpty) return null;

      final color = await _extractDominantColor(bytes);
      if (color == null) return null;

      _colorCache[imageUrl] = color;
      return color;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _loadImageBytes(String imageUrl) async {
    if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
      final path = imageUrl.startsWith('file://')
          ? imageUrl.substring(7)
          : imageUrl;
      final file = File(path);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    }

    final file = await ImageCacheManager.instance.getSingleFile(imageUrl);
    return file.readAsBytes();
  }

  static Future<Color?> _extractDominantColor(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 36,
      targetHeight: 36,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final pixels = byteData.buffer.asUint8List();
    double weightedR = 0;
    double weightedG = 0;
    double weightedB = 0;
    double weightSum = 0;

    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i] / 255.0;
      final g = pixels[i + 1] / 255.0;
      final b = pixels[i + 2] / 255.0;
      final a = pixels[i + 3] / 255.0;

      if (a < 0.25) continue;

      final maxValue = [r, g, b].reduce((x, y) => x > y ? x : y);
      final minValue = [r, g, b].reduce((x, y) => x < y ? x : y);
      final saturation = maxValue == 0 ? 0.0 : (maxValue - minValue) / maxValue;
      final luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b);

      if (luminance < 0.05 || luminance > 0.95) continue;

      final colorfulnessWeight = 0.35 + (saturation * 0.65);
      final brightnessWeight = 1.0 - ((luminance - 0.5).abs() * 0.8);
      final alphaWeight = 0.4 + (a * 0.6);
      final weight = colorfulnessWeight * brightnessWeight * alphaWeight;

      weightedR += r * weight;
      weightedG += g * weight;
      weightedB += b * weight;
      weightSum += weight;
    }

    if (weightSum == 0) return null;

    final baseColor = Color.fromARGB(
      255,
      ((weightedR / weightSum) * 255).round().clamp(0, 255),
      ((weightedG / weightSum) * 255).round().clamp(0, 255),
      ((weightedB / weightSum) * 255).round().clamp(0, 255),
    );

    final hsl = HSLColor.fromColor(baseColor);
    final tunedColor = hsl
        .withSaturation((hsl.saturation + 0.18).clamp(0.25, 0.95))
        .withLightness((hsl.lightness + 0.03).clamp(0.22, 0.72))
        .toColor();

    return tunedColor;
  }
}
