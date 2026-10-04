import '../utils/box_names.dart';

/// The box that lists every library playlist. Its keys are namespaced per
/// server (`s_<id>_<playlistId>`) but the box itself is shared.
const String libraryPlaylistsBox = 'LibraryPlaylists';

/// Which boxes a client syncs for [serverId]: user library data only. Stream
/// URLs, song caches, downloaded file indexes, home feeds, diagnostics and
/// app preferences never leave the device since they are either re-derivable
/// or machine specific.
Set<String> syncedBoxNames(int serverId, Set<String> playlistIds) {
  return {
    libraryPlaylistsBox,
    libFavBoxName(serverId),
    recentlyPlayedBoxName(serverId),
    libraryArtistsBoxName(serverId),
    libraryAlbumsBoxName(serverId),
    blacklistedPlaylistBoxName(serverId),
    searchQueryBoxName(serverId),
    prevSessionDataBoxName(serverId),
    ...playlistIds.where(isSyncableBoxName),
  };
}

/// Box names the client may push/pull. Mirrors the server side restriction:
/// internal boxes (sync state, server meta) always stay local.
bool isSyncableBoxName(String name) =>
    name.isNotEmpty && !name.startsWith('_') && name.length <= 64;

/// Extracts the song-box names of every playlist stored under [serverId]
/// in the shared LibraryPlaylists box content.
Set<String> playlistSongBoxNames(
    int serverId, Map<dynamic, dynamic> libraryPlaylists) {
  final prefix = 's_${serverId}_';
  final ids = <String>{};
  for (final entry in libraryPlaylists.entries) {
    final key = entry.key.toString();
    if (!key.startsWith(prefix)) continue;
    final value = entry.value;
    if (value is Map) {
      final playlistId = value['playlistId'] ?? value['browseId'];
      if (playlistId is String && playlistId.isNotEmpty) {
        ids.add(playlistId);
      }
    }
  }
  return ids;
}
