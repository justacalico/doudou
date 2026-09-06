import 'dart:io';
import 'dart:ui' as ui;

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box box;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_l10n_test_');
    Hive.init(dir.path);
    box = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await box.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
  });

  group('localeFromPrefs', () {
    test('defaults to en_AU when no preference stored', () {
      expect(localeFromPrefs(), const Locale('en', 'AU'));
    });

    test('maps stored language codes to supported locales', () async {
      await box.put('currentAppLanguageCode', 'zh');
      expect(localeFromPrefs(), const Locale('zh'));
      await box.put('currentAppLanguageCode', 'ru');
      expect(localeFromPrefs(), const Locale('ru'));
      await box.put('currentAppLanguageCode', 'en_AU');
      expect(localeFromPrefs(), const Locale('en', 'AU'));
    });

    test('normalizes legacy Chinese codes to zh', () async {
      for (final code in ['zh_Hant', 'zh_Hans', 'zh-CN', 'zh-TW']) {
        await box.put('currentAppLanguageCode', code);
        expect(localeFromPrefs(), const Locale('zh'), reason: code);
      }
    });

    test('falls back to en_AU for unsupported codes', () async {
      await box.put('currentAppLanguageCode', 'de');
      expect(localeFromPrefs(), const Locale('en', 'AU'));
    });
  });

  group('l10nFromPrefs', () {
    test('returns Chinese strings when zh is stored', () async {
      await box.put('currentAppLanguageCode', 'zh');
      expect(l10nFromPrefs().queue, '播放队列');
      expect(l10nFromPrefs().ok, '确定');
    });

    test('returns Russian strings when ru is stored', () async {
      await box.put('currentAppLanguageCode', 'ru');
      expect(l10nFromPrefs().queue, 'Очередь');
      expect(l10nFromPrefs().quit, 'Выход');
    });

    test('returns English strings when en_AU is stored', () async {
      await box.put('currentAppLanguageCode', 'en_AU');
      expect(l10nFromPrefs().queue, 'Queue');
      expect(l10nFromPrefs().back, 'Back');
    });
  });

  group('new keys exist in all supported locales', () {
    final locales = [
      const Locale('en', 'AU'),
      const Locale('zh'),
      const Locale('ru'),
    ];

    test('plain getters are non-empty in every locale', () {
      for (final locale in locales) {
        final l10n = lookupAppLocalizations(locale);
        final values = [
          l10n.ok,
          l10n.back,
          l10n.next,
          l10n.queue,
          l10n.playingFromQueue,
          l10n.clearQueue,
          l10n.queueEmpty,
          l10n.loop,
          l10n.clear,
          l10n.noSongPlaying,
          l10n.nowPlaying,
          l10n.expandSidebar,
          l10n.recent,
          l10n.suggestions,
          l10n.proceed,
          l10n.favorite,
          l10n.volume,
          l10n.unknown,
          l10n.none,
          l10n.notSet,
          l10n.serverType,
          l10n.activeServer,
          l10n.pipedPlaylist,
          l10n.libraryPlaylist,
          l10n.playlistsCount,
          l10n.noContentAvailable,
          l10n.noAlbumsInLibrary,
          l10n.nothingHere,
          l10n.noPlaylistsAvailable,
          l10n.noSongsForAlbum,
          l10n.noSongsForPlaylist,
          l10n.unableToStartPlayback,
          l10n.trackNotAvailableOnServer,
          l10n.serverErrorPlayback,
          l10n.demoServer,
          l10n.demoServerIntro,
          l10n.demoServerContent,
          l10n.demoServerBullets,
          l10n.demoServerReset,
          l10n.demoServerExplore,
          l10n.discordRichPresence,
          l10n.showDiscordActivity,
          l10n.showDiscordActivityDes,
          l10n.discordAppId,
          l10n.discordAppIdNotSet,
          l10n.discordAppIdDialogDes,
          l10n.discordAppIdHint,
          l10n.applicationId,
          l10n.testDiscordConnection,
          l10n.setAppIdFirst,
          l10n.sendTestActivity,
          l10n.discordRpcUnavailable,
          l10n.testingDiscordConnection,
          l10n.testingDiscordRpc,
          l10n.discordRpcWorking,
          l10n.discordRpcFailed,
          l10n.doudouConnected,
          l10n.downloadDoudou,
          l10n.openInYoutubeMusic,
          l10n.showHide,
          l10n.playPause,
          l10n.prev,
          l10n.quit,
          l10n.selectExportFolder,
          l10n.selectExportFileFolder,
          l10n.selectDownloadsFolder,
          l10n.selectBackupFile,
          l10n.selectBackupFolder,
          l10n.saveBackupFile,
          l10n.savePlaybackDiagnostics,
          l10n.playbackDiagnosticsDes,
          l10n.inAppStorageDirectory,
          l10n.loadingLibraryInBackground,
          l10n.addFavoritesToStartRadio,
          l10n.additionalProvidersUnlocked,
          l10n.noPhoneConnected,
          l10n.wearPhoneHint,
          l10n.wearMoreSettings,
          l10n.tapToOpen,
          l10n.locationAppDocuments,
          l10n.locationFilesApp,
          l10n.locationDownloads,
          l10n.scrollForMoreControls,
        ];
        for (final v in values) {
          expect(v.isNotEmpty, isTrue,
              reason: 'empty value in $locale');
        }
      }
    });

    test('placeholder getters interpolate in every locale', () {
      for (final locale in locales) {
        final l10n = lookupAppLocalizations(locale);
        expect(l10n.stepXofY(2, 4), contains('2'));
        expect(l10n.stepXofY(2, 4), contains('4'));
        expect(l10n.removedFrom('Mix'), contains('Mix'));
        expect(l10n.serverErrorCode('503'), contains('503'));
        expect(l10n.traySong('Song X'), contains('Song X'));
        expect(l10n.trayAlbum('Album Y'), contains('Album Y'));
        expect(l10n.trayArtist('Artist Z'), contains('Artist Z'));
        expect(l10n.noCategoryItems('songs'), contains('songs'));
      }
    });

    test('English values match the strings they replace', () {
      final l10n = lookupAppLocalizations(const Locale('en', 'AU'));
      expect(l10n.queue, 'Queue');
      expect(l10n.playingFromQueue, 'Playing from queue');
      expect(l10n.clearQueue, 'Clear queue');
      expect(l10n.queueEmpty, 'Queue is empty');
      expect(l10n.noSongPlaying, 'No song playing');
      expect(l10n.nowPlaying, 'Now playing');
      expect(l10n.expandSidebar, 'Expand sidebar');
      expect(l10n.recent, 'Recent');
      expect(l10n.suggestions, 'Suggestions');
      expect(l10n.proceed, 'Proceed');
      expect(l10n.volume, 'Volume');
      expect(l10n.favorite, 'Favorite');
      expect(l10n.stepXofY(1, 4), 'Step 1 of 4');
      expect(l10n.removedFrom('Roadtrip'), 'Removed from Roadtrip');
      expect(l10n.serverErrorCode('404'),
          'Server error 404 while starting playback.');
      expect(l10n.unableToStartPlayback, 'Unable to start playback.');
      expect(l10n.demoServer, 'Demo server');
      expect(l10n.traySong('Song A'), 'Song: Song A');
      expect(l10n.noCategoryItems('songs'), 'No songs!');
    });
  });

  group('trKey', () {
    testWidgets('maps trending to the localized label', (tester) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('en', 'AU'),
            Locale('zh'),
            Locale('ru'),
          ],
          home: Builder(
            builder: (context) {
              result = context.trKey('Trending');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, lookupAppLocalizations(const Locale('zh')).trending);
    });
  });

  group('localizedPlaylistDescription', () {
    Playlist makePlaylist({
      bool isPipedPlaylist = false,
      bool isCloudPlaylist = true,
      String? description = 'Server description',
    }) =>
        Playlist(
          title: 'p',
          playlistId: 'id1',
          thumbnailUrl: '',
          description: description,
          isPipedPlaylist: isPipedPlaylist,
          isCloudPlaylist: isCloudPlaylist,
        );

    Future<String> pumpAndDescribe(
        WidgetTester tester, Playlist playlist, Locale locale) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('en', 'AU'),
            Locale('zh'),
            Locale('ru'),
          ],
          home: Builder(
            builder: (context) {
              result = localizedPlaylistDescription(context, playlist);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('returns piped label for piped playlists', (tester) async {
      final playlist = makePlaylist(
          isPipedPlaylist: true, description: 'Piped Playlist');
      expect(await pumpAndDescribe(tester, playlist, const Locale('en', 'AU')),
          'Piped playlist');
      expect(await pumpAndDescribe(tester, playlist, const Locale('zh')),
          'Piped 播放列表');
    });

    testWidgets('returns library label for local playlists', (tester) async {
      final playlist = makePlaylist(
          isCloudPlaylist: false, description: 'Library Playlist');
      expect(await pumpAndDescribe(tester, playlist, const Locale('en', 'AU')),
          'Library playlist');
      expect(await pumpAndDescribe(tester, playlist, const Locale('ru')),
          'Плейлист библиотеки');
    });

    testWidgets('returns stored description for cloud playlists',
        (tester) async {
      final playlist = makePlaylist(description: 'My chill mix');
      expect(await pumpAndDescribe(tester, playlist, const Locale('en', 'AU')),
          'My chill mix');
    });
  });
}
