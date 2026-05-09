import 'package:get/get.dart';

import '/ui/screens/Settings/settings_screen_controller.dart';

int currentServerId() =>
    Get.find<SettingsScreenController>().activeServerId.value ?? 0;

String libFavBoxName(int serverId) =>
    serverId == 0 ? 'LIBFAV' : 'LIBFAV_s_$serverId';

String libraryArtistsBoxName(int serverId) =>
    serverId == 0 ? 'LibraryArtists' : 'LibraryArtists_s_$serverId';

String libraryAlbumsBoxName(int serverId) =>
    serverId == 0 ? 'LibraryAlbums' : 'LibraryAlbums_s_$serverId';

String libraryPlaylistKey(int serverId, String playlistId) =>
    's_${serverId}_$playlistId';

String recentlyPlayedBoxName(int serverId) =>
    serverId == 0 ? 'LIBRP' : 'LIBRP_s_$serverId';

String homeScreenDataBoxName(int serverId) =>
    serverId == 0 ? 'homeScreenData' : 'homeScreenData_s_$serverId';

String prevSessionDataBoxName(int serverId) =>
    serverId == 0 ? 'prevSessionData' : 'prevSessionData_s_$serverId';

String searchQueryBoxName(int serverId) =>
    serverId == 0 ? 'searchQuery' : 'searchQuery_s_$serverId';

String blacklistedPlaylistBoxName(int serverId) =>
    serverId == 0 ? 'blacklistedPlaylist' : 'blacklistedPlaylist_s_$serverId';

String librarySongsCacheBoxName(int serverId) =>
    serverId == 0 ? 'LibrarySongsCache' : 'LibrarySongsCache_s_$serverId';

String libraryPlaylistsCacheBoxName(int serverId) => serverId == 0
    ? 'LibraryPlaylistsCache'
    : 'LibraryPlaylistsCache_s_$serverId';

String libraryAlbumsCacheBoxName(int serverId) =>
    serverId == 0 ? 'LibraryAlbumsCache' : 'LibraryAlbumsCache_s_$serverId';

String libraryArtistsCacheBoxName(int serverId) =>
    serverId == 0 ? 'LibraryArtistsCache' : 'LibraryArtistsCache_s_$serverId';

String librarySyncMetaBoxName(int serverId) =>
    serverId == 0 ? 'LibrarySyncMeta' : 'LibrarySyncMeta_s_$serverId';

String songsCacheBoxName(int serverId) =>
    serverId == 0 ? 'SongsCache' : 'SongsCache_s_$serverId';

String songDownloadsBoxName(int serverId) =>
    serverId == 0 ? 'SongDownloads' : 'SongDownloads_s_$serverId';

String songsUrlCacheBoxName(int serverId) =>
    serverId == 0 ? 'SongsUrlCache' : 'SongsUrlCache_s_$serverId';

String playlistSongsBoxName(String playlistId) {
  if (playlistId == 'LIBFAV') return libFavBoxName(currentServerId());
  if (playlistId == 'LIBRP') return recentlyPlayedBoxName(currentServerId());
  return playlistId;
}
