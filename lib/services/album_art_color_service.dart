import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'image_cache_manager.dart';

/// Top-level function for isolate: compute dominant color from RGBA bytes.
/// Returns ARGB value as int, or null.
int? _dominantColorFromRgbaBytes(Uint8List pixels) {
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

  final baseR = ((weightedR / weightSum) * 255).round().clamp(0, 255);
  final baseG = ((weightedG / weightSum) * 255).round().clamp(0, 255);
  final baseB = ((weightedB / weightSum) * 255).round().clamp(0, 255);

  // RGB to HSL (0-1)
  final r = baseR / 255.0, g = baseG / 255.0, b = baseB / 255.0;
  final maxV = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final minV = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final l = (maxV + minV) / 2;
  double h, s;
  if (maxV == minV) {
    h = 0;
    s = 0;
  } else {
    final d = maxV - minV;
    s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    if (maxV == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxV == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h = h / 6;
  }
  final newS = (s + 0.18).clamp(0.25, 0.95);
  final newL = (l + 0.03).clamp(0.22, 0.72);

  // HSL to RGB (h,s,l in 0-1)
  double tr, tg, tb;
  if (newS == 0) {
    tr = tg = tb = newL;
  } else {
    final q = newL < 0.5 ? newL * (1 + newS) : newL + newS - newL * newS;
    final p = 2 * newL - q;
    tr = _hueToRgb(p, q, h + 1 / 3);
    tg = _hueToRgb(p, q, h);
    tb = _hueToRgb(p, q, h - 1 / 3);
  }
  final outR = (tr * 255).round().clamp(0, 255);
  final outG = (tg * 255).round().clamp(0, 255);
  final outB = (tb * 255).round().clamp(0, 255);
  return (255 << 24) | (outR << 16) | (outG << 8) | outB;
}

double _hueToRgb(double p, double q, double t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

class AlbumArtColorService {
  static final Map<String, Color> _colorCache = <String, Color>{};
  static final Map<String, List<Color>> _gradientCache = <String, List<Color>>{};

  /// Returns 3 colors for a gradient (top to bottom) derived from album art,
  /// darkened for use as an overlay background. Returns null on failure.
  static Future<List<Color>?> getGradientColors(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    final cached = _gradientCache[imageUrl];
    if (cached != null) return cached;

    final dominant = await getDominantGlowColor(imageUrl);
    if (dominant == null) return null;

    final hsl = HSLColor.fromColor(dominant);
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = hsl.lightness;

    // Darken and desaturate for overlay readability: top (slightly lighter) -> bottom (very dark)
    final color1 = HSLColor.fromAHSL(1, h, (s * 0.7).clamp(0.15, 0.9),
            (l * 0.35).clamp(0.08, 0.35))
        .toColor();
    final color2 = HSLColor.fromAHSL(1, h, (s * 0.5).clamp(0.1, 0.8),
            (l * 0.18).clamp(0.05, 0.22))
        .toColor();
    final color3 = HSLColor.fromAHSL(1, h, (s * 0.35).clamp(0.05, 0.6),
            (l * 0.08).clamp(0.03, 0.12))
        .toColor();

    final list = [color1, color2, color3];
    _gradientCache[imageUrl] = list;
    return list;
  }

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
    // Decode on main isolate (brief); pixel loop runs in background isolate.
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
    final pixelsCopy = Uint8List.fromList(pixels);
    final value = await compute(_dominantColorFromRgbaBytes, pixelsCopy);
    if (value == null) return null;
    return Color(value);
  }
}
