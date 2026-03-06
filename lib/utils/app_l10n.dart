import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String trKey(String key) {
    final k = key.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final l = l10n;
    switch (k) {
      case 'songs':
        return l.songs;
      case 'videos':
        return l.videos;
      case 'albums':
        return l.albums;
      case 'playlists':
        return l.playlists;
      case 'artists':
        return l.artists;
      case 'results':
        return l.results;
      case 'quickpicks':
        return l.quickpicks;
      default:
        return key;
    }
  }
}
