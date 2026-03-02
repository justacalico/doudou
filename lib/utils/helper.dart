import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '/ui/navigator.dart';
import '/ui/widgets/sort_widget.dart';

void printERROR(dynamic text, {String tag = "Doudou"}) {
  if (kReleaseMode) return;
  debugPrint("\x1B[31m[$tag]: $text\x1B[0m");
}

void printWarning(dynamic text, {String tag = 'Doudou'}) {
  if (kReleaseMode) return;
  debugPrint("\x1B[33m[$tag]: $text\x1B[34m");
}

void printINFO(dynamic text, {String tag = 'Doudou'}) {
  if (kReleaseMode) return;
  debugPrint("\x1B[32m[$tag]: $text\x1B[34m");
}

String? getCurrentRouteName() {
  String? currentPath;
  ScreenNavigationSetup.contentState?.popUntil((route) {
    currentPath = route.settings.name;
    return true;
  });
  return currentPath;
}

void sortSongsNVideos(
  List songlist,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Date:
      compareFunction = (a, b) {
        if (a.extras!['date'] == null || b.extras!['date'] == null) {
          return 0.compareTo(0);
        }
        return a.extras!['date'].compareTo(b.extras!['date']);
      };
      break;
    case SortType.Duration:
      compareFunction = (a, b) =>
          (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero);
    case SortType.Name:
    default:
      compareFunction =
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      break;
  }

  songlist.sort(compareFunction);

  if (!isAscending) {
    List reversed = songlist.reversed.toList();
    songlist.clear();
    songlist.addAll(reversed);
  }
}

void sortAlbumNSingles(
  List albumList,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Date:
      compareFunction =
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      break;
    case SortType.Name:
    default:
      compareFunction = (a, b) {
        if (a.year == null || b.year == null) {
          return 0.compareTo(0);
        }
        return a.year!.compareTo(b.year!);
      };
      break;
  }

  albumList.sort(compareFunction);

  if (!isAscending) {
    List reversed = albumList.reversed.toList();
    albumList.clear();
    albumList.addAll(reversed);
  }
}

void sortPlayLists(
  List playlists,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;
  int titleSort(a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());

  switch (sortType) {
    case SortType.RecentlyPlayed:
      compareFunction = (a, b) {
        DateTime? alp = a.lastPlayed;
        DateTime? blp = b.lastPlayed;
        if (alp == null && blp == null) {
          return titleSort(a, b);
        }
        if (alp == null) {
          return 1;
        }
        if (blp == null) {
          return -1;
        }
        return blp.compareTo(alp);
      };
      break;
    case SortType.Name:
    default:
      compareFunction = titleSort;
      break;
  }

  playlists.sort(compareFunction);

  if (!isAscending) {
    List reversed = playlists.reversed.toList();
    playlists.clear();
    playlists.addAll(reversed);
  }
}

void sortArtist(
  List artistList,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Name:
    default:
      compareFunction =
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
      break;
  }

  artistList.sort(compareFunction);

  if (!isAscending) {
    List reversed = artistList.reversed.toList();
    artistList.clear();
    artistList.addAll(reversed);
  }
}

const _openlystLatestUrl =
    'https://openlyst.ink/api/v1/apps/doudou/latest';

/// Returns the latest version string if a newer version is available, null otherwise (OpenLyst API).
Future<String?> newVersionCheck(String currentVersion) async {
  try {
    final res = await Dio().get(_openlystLatestUrl);
    final data = res.data;
    if (data is! Map || data['success'] != true) return null;
    final versionData = data['data'];
    if (versionData is! Map) return null;
    final latest = versionData['version'] as String?;
    if (latest == null || latest.isEmpty) return null;
    return _isNewerVersion(latest, currentVersion) ? latest : null;
  } catch (e) {
    return null;
  }
}

bool _isNewerVersion(String latest, String current) {
  final cur = current.replaceFirst(RegExp(r'^[Vv]'), '').split('.').map(_parseInt).toList();
  final lat = latest.split('.').map(_parseInt).toList();
  final len = lat.length > cur.length ? lat.length : cur.length;
  for (var i = 0; i < len; i++) {
    final l = i < lat.length ? lat[i] : 0;
    final c = i < cur.length ? cur[i] : 0;
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}

int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

String getTimeString(Duration time) {
  final minutes = time.inMinutes.remainder(Duration.minutesPerHour).toString();
  final seconds = time.inSeconds
      .remainder(Duration.secondsPerMinute)
      .toString()
      .padLeft(2, '0');
  return time.inHours > 0
      ? "${time.inHours}:${minutes.padLeft(2, "0")}:$seconds"
      : "$minutes:$seconds";
}
