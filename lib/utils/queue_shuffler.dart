import 'dart:math';

import 'package:audio_service/audio_service.dart';

/// Returns a shuffled copy of [items] where entries sharing the same
/// [keyOf] group are spread through the result instead of clumping
/// together the way a plain random permutation does.
///
/// Each group is shuffled internally, then its members are placed at
/// evenly spaced offsets with random jitter across the queue. A final
/// pass fixes any remaining same-group adjacencies when avoidable.
List<T> spreadShuffle<T>(List<T> items, String Function(T item) keyOf,
    {Random? random}) {
  final n = items.length;
  if (n < 3) {
    return items.toList()..shuffle(random);
  }
  final rng = random ?? Random();

  final groupIndexByKey = <String, int>{};
  final groups = <List<int>>[];
  for (var i = 0; i < n; i++) {
    final key = keyOf(items[i]);
    final g = groupIndexByKey[key];
    if (g == null) {
      groupIndexByKey[key] = groups.length;
      groups.add([i]);
    } else {
      groups[g].add(i);
    }
  }

  for (final g in groups) {
    g.shuffle(rng);
  }

  final placed = <({double pos, int index})>[];
  for (final g in groups) {
    final spacing = n / g.length;
    for (var j = 0; j < g.length; j++) {
      placed.add((pos: (j + rng.nextDouble()) * spacing, index: g[j]));
    }
  }
  placed.sort((a, b) => a.pos.compareTo(b.pos));
  final order = placed.map((p) => items[p.index]).toList();

  var i = 1;
  while (i < n) {
    if (keyOf(order[i]) != keyOf(order[i - 1])) {
      i++;
      continue;
    }
    final key = keyOf(order[i]);
    var j = i + 1;
    while (j < n) {
      final candidate = keyOf(order[j]);
      if (candidate != key &&
          keyOf(order[j - 1]) != key &&
          (j + 1 >= n || keyOf(order[j + 1]) != key) &&
          (i + 1 >= n || candidate != keyOf(order[i + 1]))) {
        break;
      }
      j++;
    }
    if (j < n) {
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    i++;
  }
  return order;
}

String _songGroupKey(MediaItem item) {
  final artist = item.artist?.trim().toLowerCase();
  if (artist != null && artist.isNotEmpty) return 'a:$artist';
  final album = item.album?.trim().toLowerCase();
  if (album != null && album.isNotEmpty) return 'l:$album';
  return 'i:${item.id}';
}

/// Shuffles [songs] so tracks by the same artist (falling back to album)
/// are spread through the result instead of clumping together.
List<MediaItem> shuffledSongs(List<MediaItem> songs, {Random? random}) =>
    spreadShuffle(songs, _songGroupKey, random: random);
