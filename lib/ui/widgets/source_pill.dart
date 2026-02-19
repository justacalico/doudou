import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/base_service.dart';
import '../theme.dart';

/// Small colored badge for track source. Used on track tiles and now playing bar.
class SourcePill extends StatelessWidget {
  final ServerType source;
  final double fontSize;

  const SourcePill({super.key, required this.source, this.fontSize = 10});

  static Color colorFor(ServerType type) {
    switch (type) {
      case ServerType.soundcloud:
        return const Color(0xFFFF5500); // orange
      case ServerType.youtubeMusic:
        return const Color(0xFFFF0000); // red
      case ServerType.jellyfin:
        return const Color(0xFF9B59B6); // purple
      case ServerType.plex:
        return const Color(0xFFE5A00D); // yellow
      case ServerType.subsonic:
        return const Color(0xFF3498DB); // blue
      case ServerType.local:
        return const Color(0xFF95A5A6); // grey
    }
  }

  static String labelFor(ServerType type) {
    switch (type) {
      case ServerType.soundcloud:
        return 'SoundCloud';
      case ServerType.youtubeMusic:
        return 'YouTube Music';
      case ServerType.jellyfin:
        return 'Jellyfin';
      case ServerType.plex:
        return 'Plex';
      case ServerType.subsonic:
        return 'Subsonic';
      case ServerType.local:
        return 'Local';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(source);
    final label = labelFor(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
