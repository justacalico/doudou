// Hallmark · macrostructure: Split Studio · H2 hero knobs: ratio=6/6, right=screenshot pair, divider=negative space
// theme: custom · vibe: "apple-keynote clean, product violet" · paper oklch(98% 0.006 293) · accent oklch(50% 0.20 293) violet
// display: Geist · body: Geist · axes: light / geometric-sans / chromatic-violet
// nav: N9 edge-aligned · footer: Ft2 inline single line · context: user-provided
// Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V5
// contrast: pass (40-41) · honest: pass (46) · chrome: pass (47) · tokens: pass (48) · responsive: pass (49) · icons: pass (30) · mobile: pass (34, 50-57)
import 'package:flutter/widgets.dart';

/// Design tokens. Every colour is tinted toward the violet anchor (hue ~293)
/// so the neutrals lean violet instead of reading flat grey.
abstract final class Tk {
  static const paper = Color(0xFFFBFAFD); // oklch(98% 0.006 293)
  static const paper2 = Color(0xFFF2F1F6); // oklch(95% 0.008 293)
  static const ink = Color(0xFF1F1C29); // oklch(21% 0.012 293)
  static const ink2 = Color(0xFF4A4659); // oklch(33% 0.012 293)
  static const muted = Color(0xFF6A657C); // oklch(46% 0.010 293)
  static const rule = Color(0xFFDFDDE7); // oklch(88% 0.008 293)
  static const rule2 = Color(0xFFECE9F2); // oklch(92% 0.007 293)
  static const accent = Color(0xFF7C3AED); // brand violet
  static const accentDeep = Color(0xFF6428D8); // hover step
  static const accentInk = paper; // text on accent fill

  static const space3xs = 2.0;
  static const space2xs = 4.0;
  static const spaceXs = 8.0;
  static const spaceSm = 12.0;
  static const spaceMd = 16.0;
  static const spaceLg = 24.0;
  static const spaceXl = 40.0;
  static const space2xl = 64.0;
  static const space3xl = 96.0;
  static const space4xl = 144.0;

  static const durMicro = Duration(milliseconds: 120);
  static const durShort = Duration(milliseconds: 220);
  static const durLong = Duration(milliseconds: 420);

  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  static const easeIn = Cubic(0.7, 0, 0.84, 0);
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);

  /// Display size that scales with viewport width like a CSS clamp().
  static double displaySize(double width) =>
      (width * 0.055 + 16).clamp(40.0, 76.0);

  static double headlineSize(double width) => width < 640 ? 30.0 : 40.0;

  /// Horizontal page padding, wider on wide screens. Values stay on the
  /// 4 pt spacing scale.
  static double pagePadding(double width) =>
      width < 640 ? spaceLg : (width < 960 ? spaceXl : space2xl);

  /// Diptychs and grids switch to side-by-side at this width.
  static const wide = 880.0;
}
