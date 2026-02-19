/// Display helpers for UI (e.g. deduplicating artist names).
library;

import '../models/jellyfin_models.dart';

/// Prefix for virtual album IDs (artist albums derived from tracks, e.g. YouTube Music).
/// Resolved in service getPlaylistTracks as 'ytm_album:artistId:albumName'.
const String virtualAlbumIdPrefix = 'ytm_album:';

/// Build a list of albums by grouping [tracks] by album (albumId or albumName).
/// Used for providers (e.g. YouTube Music) that don't expose albums directly but
/// tracks include album info. When [artistId] is set and track has no albumId,
/// uses a virtual id [virtualAlbumIdPrefix]artistId:albumName so the service can
/// resolve album tracks.
List<Album> albumsFromTracks(List<Track> tracks, {String? artistName, String? artistId}) {
  final byAlbum = <String, List<Track>>{};
  for (final t in tracks) {
    final id = t.albumId ?? t.albumName ?? '';
    final key = id.isEmpty ? 'Unknown Album' : id;
    byAlbum.putIfAbsent(key, () => []).add(t);
  }
  final albums = <Album>[];
  for (final entry in byAlbum.entries) {
    final list = entry.value;
    final first = list.first;
    final name = first.albumName ?? (entry.key == 'Unknown Album' ? 'Unknown Album' : entry.key);
    String id = first.albumId ?? 'album_${name.hashCode.abs()}';
    if (first.albumId == null && artistId != null && name != 'Unknown Album') {
      final safeName = name.replaceAll(':', '_');
      id = '$virtualAlbumIdPrefix$artistId:$safeName';
    }
    albums.add(Album(
      id: id,
      name: name,
      artistName: artistName ?? first.artistName,
      imageUrl: first.imageUrl,
      year: null,
      isFavorite: false,
    ));
  }
  albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return albums;
}

/// Returns a display string for artist name(s). When the same artist is
/// repeated in a comma-separated list (e.g. "Nia Nicholls, Nia Nicholls, Nia Nicholls"),
/// returns a single instance (e.g. "Nia Nicholls"). Multiple distinct artists
/// are preserved and deduplicated in order.
/// [defaultName] is returned when the result would otherwise be empty.
String displayArtistName(String? artistName, {String defaultName = ''}) {
  if (artistName == null || artistName.isEmpty) return defaultName;
  final parts = artistName
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return defaultName;
  final seen = <String>{};
  final unique = <String>[];
  for (final p in parts) {
    if (seen.add(p)) unique.add(p);
  }
  final result = unique.join(', ');
  return result.isEmpty ? defaultName : result;
}
