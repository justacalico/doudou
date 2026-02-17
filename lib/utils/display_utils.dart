/// Display helpers for UI (e.g. deduplicating artist names).

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
