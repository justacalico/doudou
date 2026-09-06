import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';
import '../models/playlist.dart';

/// Resolves the stored app language code to a [Locale] for the generated
/// localizations. Used by code that has no [BuildContext] (system tray,
/// Android Auto, Discord RPC, background services).
Locale localeFromPrefs() {
  String code = 'en_AU';
  try {
    code = Hive.box('AppPrefs').get('currentAppLanguageCode') ?? 'en_AU';
  } catch (_) {}
  const supported = ['en_AU', 'zh', 'ru'];
  final normalized = code == 'zh_Hant' ||
          code == 'zh_Hans' ||
          code == 'zh-CN' ||
          code == 'zh-TW'
      ? 'zh'
      : supported.contains(code)
          ? code
          : 'en_AU';
  return normalized == 'en_AU' ? const Locale('en', 'AU') : Locale(normalized);
}

/// Localizations for the language stored in AppPrefs, usable without a
/// [BuildContext].
AppLocalizations l10nFromPrefs() => lookupAppLocalizations(localeFromPrefs());

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
      case 'featuredplaylists':
        return l.featuredplaylists;
      case 'communityplaylists':
        return l.communityplaylists;
      case 'trending':
        return l.trending;
      case 'librarysongs':
        return l.libSongs;
      default:
        return key;
    }
  }
}

/// Localized display text for a playlist description. App-created playlists
/// store fixed English markers ("Piped Playlist", "Library Playlist"), so the
/// flags are used to return the localized label instead of the stored value.
String localizedPlaylistDescription(BuildContext context, Playlist playlist) {
  if (playlist.isPipedPlaylist) return context.l10n.pipedPlaylist;
  if (!playlist.isCloudPlaylist) return context.l10n.libraryPlaylist;
  return playlist.description ?? '';
}
