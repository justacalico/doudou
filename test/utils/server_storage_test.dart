import 'package:doudou/utils/server_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('libFavBoxName', () {
    test('returns LIBFAV for server 0', () {
      expect(libFavBoxName(0), 'LIBFAV');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libFavBoxName(3), 'LIBFAV_s_3');
    });
  });

  group('libraryArtistsBoxName', () {
    test('returns LibraryArtists for server 0', () {
      expect(libraryArtistsBoxName(0), 'LibraryArtists');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libraryArtistsBoxName(2), 'LibraryArtists_s_2');
    });
  });

  group('libraryAlbumsBoxName', () {
    test('returns LibraryAlbums for server 0', () {
      expect(libraryAlbumsBoxName(0), 'LibraryAlbums');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libraryAlbumsBoxName(5), 'LibraryAlbums_s_5');
    });
  });

  group('libraryPlaylistKey', () {
    test('builds key from serverId and playlistId', () {
      expect(libraryPlaylistKey(1, 'PL123'), 's_1_PL123');
    });

    test('handles server 0', () {
      expect(libraryPlaylistKey(0, 'PL'), 's_0_PL');
    });
  });

  group('recentlyPlayedBoxName', () {
    test('returns LIBRP for server 0', () {
      expect(recentlyPlayedBoxName(0), 'LIBRP');
    });

    test('returns suffixed name for non-zero server', () {
      expect(recentlyPlayedBoxName(1), 'LIBRP_s_1');
    });
  });

  group('homeScreenDataBoxName', () {
    test('returns homeScreenData for server 0', () {
      expect(homeScreenDataBoxName(0), 'homeScreenData');
    });

    test('returns suffixed name for non-zero server', () {
      expect(homeScreenDataBoxName(4), 'homeScreenData_s_4');
    });
  });

  group('prevSessionDataBoxName', () {
    test('returns prevSessionData for server 0', () {
      expect(prevSessionDataBoxName(0), 'prevSessionData');
    });

    test('returns suffixed name for non-zero server', () {
      expect(prevSessionDataBoxName(2), 'prevSessionData_s_2');
    });
  });

  group('searchQueryBoxName', () {
    test('returns searchQuery for server 0', () {
      expect(searchQueryBoxName(0), 'searchQuery');
    });

    test('returns suffixed name for non-zero server', () {
      expect(searchQueryBoxName(7), 'searchQuery_s_7');
    });
  });

  group('blacklistedPlaylistBoxName', () {
    test('returns blacklistedPlaylist for server 0', () {
      expect(blacklistedPlaylistBoxName(0), 'blacklistedPlaylist');
    });

    test('returns suffixed name for non-zero server', () {
      expect(blacklistedPlaylistBoxName(1), 'blacklistedPlaylist_s_1');
    });
  });

  group('librarySongsCacheBoxName', () {
    test('returns LibrarySongsCache for server 0', () {
      expect(librarySongsCacheBoxName(0), 'LibrarySongsCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(librarySongsCacheBoxName(3), 'LibrarySongsCache_s_3');
    });
  });

  group('libraryPlaylistsCacheBoxName', () {
    test('returns LibraryPlaylistsCache for server 0', () {
      expect(libraryPlaylistsCacheBoxName(0), 'LibraryPlaylistsCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libraryPlaylistsCacheBoxName(2), 'LibraryPlaylistsCache_s_2');
    });
  });

  group('libraryAlbumsCacheBoxName', () {
    test('returns LibraryAlbumsCache for server 0', () {
      expect(libraryAlbumsCacheBoxName(0), 'LibraryAlbumsCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libraryAlbumsCacheBoxName(1), 'LibraryAlbumsCache_s_1');
    });
  });

  group('libraryArtistsCacheBoxName', () {
    test('returns LibraryArtistsCache for server 0', () {
      expect(libraryArtistsCacheBoxName(0), 'LibraryArtistsCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(libraryArtistsCacheBoxName(6), 'LibraryArtistsCache_s_6');
    });
  });

  group('librarySyncMetaBoxName', () {
    test('returns LibrarySyncMeta for server 0', () {
      expect(librarySyncMetaBoxName(0), 'LibrarySyncMeta');
    });

    test('returns suffixed name for non-zero server', () {
      expect(librarySyncMetaBoxName(2), 'LibrarySyncMeta_s_2');
    });
  });

  group('songsCacheBoxName', () {
    test('returns SongsCache for server 0', () {
      expect(songsCacheBoxName(0), 'SongsCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(songsCacheBoxName(1), 'SongsCache_s_1');
    });
  });

  group('songDownloadsBoxName', () {
    test('returns SongDownloads for server 0', () {
      expect(songDownloadsBoxName(0), 'SongDownloads');
    });

    test('returns suffixed name for non-zero server', () {
      expect(songDownloadsBoxName(3), 'SongDownloads_s_3');
    });
  });

  group('songsUrlCacheBoxName', () {
    test('returns SongsUrlCache for server 0', () {
      expect(songsUrlCacheBoxName(0), 'SongsUrlCache');
    });

    test('returns suffixed name for non-zero server', () {
      expect(songsUrlCacheBoxName(4), 'SongsUrlCache_s_4');
    });
  });
}
