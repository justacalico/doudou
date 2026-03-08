import 'package:flutter/material.dart';

import '/utils/app_l10n.dart';

enum ContentCategory {
  songs,
  videos,
  albums,
  singles,
  artists,
  playlists,
  featuredPlaylists,
  communityPlaylists,
  downloads,
  results,
  unknown,
}

extension ContentCategoryX on ContentCategory {
  String get canonicalKey {
    switch (this) {
      case ContentCategory.songs:
        return 'Songs';
      case ContentCategory.videos:
        return 'Videos';
      case ContentCategory.albums:
        return 'Albums';
      case ContentCategory.singles:
        return 'Singles';
      case ContentCategory.artists:
        return 'Artists';
      case ContentCategory.playlists:
        return 'Playlists';
      case ContentCategory.featuredPlaylists:
        return 'Featured playlists';
      case ContentCategory.communityPlaylists:
        return 'Community playlists';
      case ContentCategory.downloads:
        return 'Downloads';
      case ContentCategory.results:
        return 'Results';
      case ContentCategory.unknown:
        return 'Unknown';
    }
  }

  String localizedLabel(BuildContext context) {
    switch (this) {
      case ContentCategory.songs:
        return context.l10n.songs;
      case ContentCategory.videos:
        return context.l10n.videos;
      case ContentCategory.albums:
        return context.l10n.albums;
      case ContentCategory.singles:
        return context.l10n.singles;
      case ContentCategory.artists:
        return context.l10n.artists;
      case ContentCategory.playlists:
        return context.l10n.playlists;
      case ContentCategory.featuredPlaylists:
        return context.l10n.featuredplaylists;
      case ContentCategory.communityPlaylists:
        return context.l10n.communityplaylists;
      case ContentCategory.downloads:
        return context.l10n.downloads;
      case ContentCategory.results:
        return context.l10n.results;
      case ContentCategory.unknown:
        return canonicalKey;
    }
  }

  bool get isSongLike =>
      this == ContentCategory.songs || this == ContentCategory.videos;

  bool get isAlbumLike =>
      this == ContentCategory.albums || this == ContentCategory.singles;

  bool get isArtistLike => this == ContentCategory.artists;

  bool get isPlaylistLike =>
      this == ContentCategory.playlists ||
      this == ContentCategory.featuredPlaylists ||
      this == ContentCategory.communityPlaylists;
}

class ContentCategoryMapper {
  static final Map<String, ContentCategory> _normalizedLookup = {
    'songs': ContentCategory.songs,
    'videos': ContentCategory.videos,
    'albums': ContentCategory.albums,
    'singles': ContentCategory.singles,
    'artists': ContentCategory.artists,
    'playlists': ContentCategory.playlists,
    'featuredplaylists': ContentCategory.featuredPlaylists,
    'communityplaylists': ContentCategory.communityPlaylists,
    'downloads': ContentCategory.downloads,
    'results': ContentCategory.results,
  };

  static String normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  static ContentCategory fromKey(String? key) {
    if (key == null || key.trim().isEmpty) return ContentCategory.unknown;
    return _normalizedLookup[normalizeKey(key)] ?? ContentCategory.unknown;
  }

  static const List<ContentCategory> artistTabs = [
    ContentCategory.songs,
    ContentCategory.videos,
    ContentCategory.albums,
    ContentCategory.singles,
  ];
}
