import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import 'app_theme_provider.dart';

final nowPlayingAccentProvider =
    StateNotifierProvider<NowPlayingAccentController, String?>(
  (ref) => NowPlayingAccentController(ref),
);

class NowPlayingAccentController extends StateNotifier<String?> {
  NowPlayingAccentController(this._ref) : super(null);

  final Ref _ref;
  int _token = 0;
  static const _fallbackAccent = Color(0xFFE8A598);

  Future<void> setFromArtwork(ImageProvider imageProvider, String songId) async {
    if (state == songId) return;
    state = songId;
    final token = ++_token;

    PaletteGenerator generator;
    try {
      generator = await PaletteGenerator.fromImageProvider(
        ResizeImage(imageProvider, width: 200, height: 200),
      );
    } catch (_) {
      return;
    }

    if (token != _token) return;
    final accent = _normalizeArtworkAccent(
      _pickAccent(generator) ?? _fallbackAccent,
    );
    _ref.read(appThemeProvider.notifier).setAccent(accent);
  }

  Color? _pickAccent(PaletteGenerator generator) {
    final source = <PaletteColor?>[
      generator.vibrantColor,
      generator.darkVibrantColor,
      generator.lightVibrantColor,
      generator.dominantColor,
      generator.mutedColor,
      generator.darkMutedColor,
      generator.lightMutedColor,
    ];
    final byColor = <int, PaletteColor>{};
    for (final c in source) {
      if (c == null) continue;
      byColor[c.color.toARGB32()] = c;
    }
    if (byColor.isEmpty) return null;

    final candidates = byColor.values.toList(growable: false);
    var maxPopulation = 1;
    for (final candidate in candidates) {
      if (candidate.population > maxPopulation) {
        maxPopulation = candidate.population;
      }
    }

    candidates.sort((a, b) {
      final scoreA = _scoreCandidate(a, maxPopulation);
      final scoreB = _scoreCandidate(b, maxPopulation);
      return scoreB.compareTo(scoreA);
    });
    return candidates.first.color;
  }

  double _scoreCandidate(PaletteColor c, int maxPopulation) {
    final popNorm = c.population / maxPopulation;
    final hsl = HSLColor.fromColor(c.color);
    final saturation = hsl.saturation;
    final lightness = hsl.lightness;
    final contrastFit =
        (1.0 - ((lightness - 0.48).abs() * 2.0)).clamp(0.0, 1.0);
    var score = (saturation * 0.65) + (popNorm * 0.25) + (contrastFit * 0.10);

    if (saturation < 0.22) score -= 0.20;
    if (saturation < 0.30 && lightness >= 0.42 && lightness <= 0.74) {
      score -= 0.15;
    }
    if (saturation >= 0.55 && lightness >= 0.28 && lightness <= 0.62) {
      score += 0.12;
    }
    return score;
  }

  Color _normalizeArtworkAccent(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.90))
        .withLightness(hsl.lightness.clamp(0.34, 0.58))
        .toColor();
  }
}

