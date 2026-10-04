import 'package:doudou/server/sync_boxes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('syncedBoxNames', () {
    test('covers the user data boxes for the default server', () {
      final names = syncedBoxNames(0, {'PL1'});
      expect(names, containsAll([
        'LibraryPlaylists',
        'LIBFAV',
        'LIBRP',
        'LibraryArtists',
        'LibraryAlbums',
        'blacklistedPlaylist',
        'searchQuery',
        'prevSessionData',
        'PL1',
      ]));
    });

    test('uses the per server suffix for non default servers', () {
      final names = syncedBoxNames(3, const {});
      expect(names, contains('LIBFAV_s_3'));
      expect(names, contains('LIBRP_s_3'));
      expect(names, isNot(contains('LIBFAV')));
      expect(names, contains('LibraryPlaylists'));
    });

    test('never syncs caches, downloads, prefs or internal state', () {
      final names = syncedBoxNames(0, {
        '_doudouSyncState',
        'PL2',
      });
      for (final forbidden in [
        'AppPrefs',
        'SongDownloads',
        'SongsCache',
        'SongsUrlCache',
        'homeScreenData',
        'LibrarySongsCache',
        '_doudouSyncState',
        '_doudouMeta',
      ]) {
        expect(names, isNot(contains(forbidden)),
            reason: '$forbidden must stay local');
      }
      expect(names, contains('PL2'));
    });
  });

  group('playlistSongBoxNames', () {
    test('extracts playlist ids for the given server only', () {
      final boxContent = {
        's_0_AAA': {'playlistId': 'AAA', 'title': 'a'},
        's_0_BBB': {'browseId': 'BBB', 'title': 'b'},
        's_2_CCC': {'playlistId': 'CCC', 'title': 'other server'},
        'junk': 'not a map',
      };
      expect(playlistSongBoxNames(0, boxContent), {'AAA', 'BBB'});
      expect(playlistSongBoxNames(2, boxContent), {'CCC'});
    });

    test('returns empty for missing or malformed values', () {
      expect(playlistSongBoxNames(0, const {}), isEmpty);
      expect(
        playlistSongBoxNames(0, {
          's_0_X': {'title': 'no id'},
          's_0_Y': 42,
        }),
        isEmpty,
      );
    });
  });
}
