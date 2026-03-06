import 'package:flutter/material.dart';

@immutable
class DoudouColors extends ThemeExtension<DoudouColors> {
  const DoudouColors({
    required this.appBackground,
    required this.raisedBackground,
    required this.surfaceBase,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.surfaceModal,
    required this.surfaceSelected,
    required this.stateHover,
    required this.statePressed,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accentPrimary,
    required this.accentMuted,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.artworkScrimTop,
    required this.artworkScrimBottom,
    required this.playerBackdropLow,
    required this.playerBackdropHigh,
  });

  final Color appBackground;
  final Color raisedBackground;
  final Color surfaceBase;
  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color surfaceModal;
  final Color surfaceSelected;
  final Color stateHover;
  final Color statePressed;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color accentPrimary;
  final Color accentMuted;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color error;
  final Color artworkScrimTop;
  final Color artworkScrimBottom;
  final Color playerBackdropLow;
  final Color playerBackdropHigh;

  @override
  DoudouColors copyWith({
    Color? appBackground,
    Color? raisedBackground,
    Color? surfaceBase,
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? surfaceModal,
    Color? surfaceSelected,
    Color? stateHover,
    Color? statePressed,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? accentPrimary,
    Color? accentMuted,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? error,
    Color? artworkScrimTop,
    Color? artworkScrimBottom,
    Color? playerBackdropLow,
    Color? playerBackdropHigh,
  }) {
    return DoudouColors(
      appBackground: appBackground ?? this.appBackground,
      raisedBackground: raisedBackground ?? this.raisedBackground,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      surfaceModal: surfaceModal ?? this.surfaceModal,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      stateHover: stateHover ?? this.stateHover,
      statePressed: statePressed ?? this.statePressed,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      artworkScrimTop: artworkScrimTop ?? this.artworkScrimTop,
      artworkScrimBottom: artworkScrimBottom ?? this.artworkScrimBottom,
      playerBackdropLow: playerBackdropLow ?? this.playerBackdropLow,
      playerBackdropHigh: playerBackdropHigh ?? this.playerBackdropHigh,
    );
  }

  @override
  DoudouColors lerp(ThemeExtension<DoudouColors>? other, double t) {
    if (other is! DoudouColors) return this;
    return DoudouColors(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      raisedBackground: Color.lerp(raisedBackground, other.raisedBackground, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      surfaceModal: Color.lerp(surfaceModal, other.surfaceModal, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      stateHover: Color.lerp(stateHover, other.stateHover, t)!,
      statePressed: Color.lerp(statePressed, other.statePressed, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      artworkScrimTop: Color.lerp(artworkScrimTop, other.artworkScrimTop, t)!,
      artworkScrimBottom:
          Color.lerp(artworkScrimBottom, other.artworkScrimBottom, t)!,
      playerBackdropLow:
          Color.lerp(playerBackdropLow, other.playerBackdropLow, t)!,
      playerBackdropHigh:
          Color.lerp(playerBackdropHigh, other.playerBackdropHigh, t)!,
    );
  }
}

extension DoudouThemeX on BuildContext {
  DoudouColors get doudouColors {
    final ext = Theme.of(this).extension<DoudouColors>();
    if (ext != null) return ext;

    return const DoudouColors(
      appBackground: Color(0xFF0A0A0C),
      raisedBackground: Color(0xFF111115),
      surfaceBase: Color(0xFF14141A),
      surfaceElevated: Color(0xFF1A1A22),
      surfaceOverlay: Color(0xCC121219),
      surfaceModal: Color(0xFF17171F),
      surfaceSelected: Color(0xFF20202A),
      stateHover: Color(0x14FFFFFF),
      statePressed: Color(0x1FFFFFFF),
      borderSubtle: Color(0x14FFFFFF),
      borderStrong: Color(0x24FFFFFF),
      textPrimary: Color(0xFFF4F4F5),
      textSecondary: Color(0xFFB4B4BE),
      textTertiary: Color(0xFF7D7D88),
      textDisabled: Color(0xFF5A5A64),
      accentPrimary: Color(0xFFB08CFF),
      accentMuted: Color(0x66B08CFF),
      onAccent: Color(0xFF0B0B0F),
      success: Color(0xFF4ADE80),
      warning: Color(0xFFFBBF24),
      error: Color(0xFFFB7185),
      artworkScrimTop: Color(0x00000000),
      artworkScrimBottom: Color(0xD9000000),
      playerBackdropLow: Color(0xFF0A0A0C),
      playerBackdropHigh: Color(0xFF14141A),
    );
  }
}

