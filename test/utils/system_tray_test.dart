import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/utils/system_tray.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const song = MediaItem(
    id: 'song1',
    title: 'Test Song',
    album: 'Test Album',
    artist: 'Test Artist',
  );

  MenuItem? itemByLabel(Menu menu, String label) {
    for (final item in menu.items ?? <MenuItem>[]) {
      if (item.label == label) return item;
    }
    return null;
  }

  group('buildTrayMenu', () {
    test('shows checked favourite item when the song is favourited', () {
      final menu = buildTrayMenu(
        l10n: l10n,
        song: song,
        isFavourite: true,
        hasQueue: true,
      );

      final item = menu.getMenuItem('trayFavourite');
      expect(item, isNotNull);
      expect(item!.type, 'checkbox');
      expect(item.label, l10n.favorite);
      expect(item.checked, isTrue);
      expect(item.disabled, isFalse);
    });

    test('shows unchecked favourite item when the song is not favourited', () {
      final menu = buildTrayMenu(
        l10n: l10n,
        song: song,
        isFavourite: false,
        hasQueue: true,
      );

      final item = menu.getMenuItem('trayFavourite');
      expect(item, isNotNull);
      expect(item!.checked, isFalse);
    });

    test('clicking the favourite item toggles the favourite callback', () {
      var toggles = 0;
      final menu = buildTrayMenu(
        l10n: l10n,
        song: song,
        isFavourite: false,
        hasQueue: true,
        onToggleFavourite: () => toggles++,
      );

      final item = menu.getMenuItem('trayFavourite')!;
      item.onClick!(item);
      expect(toggles, 1);
    });

    test('omits song info and the favourite item when nothing is playing', () {
      final menu = buildTrayMenu(
        l10n: l10n,
        song: null,
        isFavourite: false,
        hasQueue: false,
      );

      expect(menu.getMenuItem('trayFavourite'), isNull);
      expect(itemByLabel(menu, l10n.traySong(song.title)), isNull);
      expect(itemByLabel(menu, l10n.trayAlbum(song.album!)), isNull);
      expect(itemByLabel(menu, l10n.trayArtist(song.artist!)), isNull);
    });

    test('playback controls invoke callbacks only when a queue exists', () {
      var prev = 0;
      var playPause = 0;
      var next = 0;

      final noQueueMenu = buildTrayMenu(
        l10n: l10n,
        song: null,
        isFavourite: false,
        hasQueue: false,
        onPrev: () => prev++,
        onPlayPause: () => playPause++,
        onNext: () => next++,
      );
      itemByLabel(noQueueMenu, l10n.prev)!.onClick!(MenuItem());
      itemByLabel(noQueueMenu, l10n.playPause)!.onClick!(MenuItem());
      itemByLabel(noQueueMenu, l10n.next)!.onClick!(MenuItem());
      expect(prev, 0);
      expect(playPause, 0);
      expect(next, 0);

      final queueMenu = buildTrayMenu(
        l10n: l10n,
        song: song,
        isFavourite: false,
        hasQueue: true,
        onPrev: () => prev++,
        onPlayPause: () => playPause++,
        onNext: () => next++,
      );
      itemByLabel(queueMenu, l10n.prev)!.onClick!(MenuItem());
      itemByLabel(queueMenu, l10n.playPause)!.onClick!(MenuItem());
      itemByLabel(queueMenu, l10n.next)!.onClick!(MenuItem());
      expect(prev, 1);
      expect(playPause, 1);
      expect(next, 1);
    });

    test('show/hide and quit invoke their callbacks', () {
      var showHide = 0;
      var quit = 0;
      final menu = buildTrayMenu(
        l10n: l10n,
        song: null,
        isFavourite: false,
        hasQueue: false,
        onShowHide: () => showHide++,
        onQuit: () => quit++,
      );

      itemByLabel(menu, l10n.showHide)!.onClick!(MenuItem());
      itemByLabel(menu, l10n.quit)!.onClick!(MenuItem());
      expect(showHide, 1);
      expect(quit, 1);
    });
  });
}
