import 'dart:io';

import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/ui/screens/Search/components/search_clear_button.dart';
import 'package:doudou/ui/screens/Search/components/search_item.dart';
import 'package:doudou/ui/screens/Search/components/search_query_bar.dart';
import 'package:doudou/ui/screens/Search/components/search_text_field.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_screen_controller.dart';
import 'package:doudou/ui/widgets/library_section_builders.dart';
import 'package:doudou/ui/widgets/search_related_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  late Directory hiveDir;
  late GoldenDeps deps;
  late FakeSearchResultScreenController resultController;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
  ];

  final albums = [
    Album(
        title: 'Golden Hour',
        browseId: 'a1',
        artists: const [
          {'name': 'Golden Artist'}
        ],
        year: '2024',
        thumbnailUrl: 'https://img.example.com/a1.jpg'),
  ];

  final playlists = [
    Playlist(
        title: 'Evening Mix',
        playlistId: 'p1',
        thumbnailUrl: 'https://img.example.com/p1.jpg'),
  ];

  final artists = [
    Artist(
        name: 'Golden Artist',
        browseId: 'ar1',
        thumbnailUrl: 'https://img.example.com/ar1.jpg',
        subscribers: '1.2M'),
  ];

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_search_');
    Hive.init(hiveDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('LibraryPlaylists');
    await Hive.openBox('searchQuery');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    deps = await installGoldenDeps(
        settings: GoldenSettingsScreenController());
    Get.put<SearchScreenController>(FakeSearchScreenController());
    resultController = FakeSearchResultScreenController();
    Get.put<SearchResultScreenController>(resultController);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('search item', (tester) async {
    await pumpGolden(
      tester,
      ListView(
        children: const [
          SearchItem(queryString: 'golden hour', isHistoryString: true),
          SearchItem(queryString: 'midnight train', isHistoryString: false),
        ],
      ),
      size: const Size(600, 240),
    );
    await expectGolden(tester, 'search_item');
  });

  testWidgets('search text field', (tester) async {
    final controller = TextEditingController(text: 'golden');
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: SearchTextField(
          controller: controller,
          onChanged: (_) {},
          onSubmitted: (_) {},
          onClear: () {},
        ),
      ),
      size: const Size(600, 140),
    );
    await expectGolden(tester, 'search_text_field');
  });

  testWidgets('search clear button', (tester) async {
    final controller = TextEditingController(text: 'golden');
    await pumpGolden(
      tester,
      Center(
        child: SearchClearButton(controller: controller, onPressed: () {}),
      ),
      size: const Size(200, 120),
    );
    await expectGolden(tester, 'search_clear_button');
  });

  testWidgets('search query bar', (tester) async {
    resultController.queryString.value = 'golden hour';
    resultController.queryEditingController.text = 'golden hour';
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: SearchQueryBar(controller: resultController),
      ),
      size: const Size(600, 140),
    );
    await expectGolden(tester, 'search_query_bar');
  });

  testWidgets('result widget', (tester) async {
    resultController.isResultContentFetched.value = true;
    resultController.queryString.value = 'golden';
    resultController.resultContent.value = {
      'Songs': songs,
      'Albums': albums,
    };
    await pumpGolden(
      tester,
      ResultWidget(searchResScrController: resultController),
      size: const Size(800, 900),
      settle: false,
    );
    await expectGolden(tester, 'result_widget');
  });

  testWidgets('library overview cards', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: buildLibraryOverviewCards(
            context,
            albumsCount: 12,
            artistsCount: 7,
            songsCount: 128,
            playlistsCount: 4,
            onSwitchToTab: (_) {},
          ),
        ),
      ),
      size: const Size(1100, 320),
    );
    await expectGolden(tester, 'library_overview_cards');
  });

  testWidgets('library track row section', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => buildTrackRowSection(
          context: context,
          title: 'Recently played',
          subtitle: 'Last songs you played',
          items: songs,
          playLabel: 'Play all',
          playerController: deps.player,
          showViewAll: true,
          onViewAll: () {},
        ),
      ),
      size: const Size(900, 400),
      settle: false,
    );
    await expectGolden(tester, 'library_track_row_section');
  });

  testWidgets('library playlist row section', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => buildPlaylistRowSection(
          context: context,
          title: 'Playlists',
          subtitle: 'Your playlists',
          playlists: playlists,
        ),
      ),
      size: const Size(900, 380),
      settle: false,
    );
    await expectGolden(tester, 'library_playlist_row_section');
  });

  testWidgets('library album row section', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => buildAlbumRowSection(
          context: context,
          title: 'Albums',
          subtitle: 'From your library',
          albums: albums,
          showViewAll: true,
          onViewAll: () {},
        ),
      ),
      size: const Size(900, 380),
      settle: false,
    );
    await expectGolden(tester, 'library_album_row_section');
  });

  testWidgets('library artist row section', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => buildArtistRowSection(
          context: context,
          title: 'Artists',
          subtitle: 'From your library',
          artists: artists,
        ),
      ),
      size: const Size(900, 380),
      settle: false,
    );
    await expectGolden(tester, 'library_artist_row_section');
  });

  testWidgets('library fresh picks section', (tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => buildFreshPicksSection(
          context: context,
          items: songs,
          playerController: deps.player,
        ),
      ),
      size: const Size(900, 500),
      settle: false,
    );
    await expectGolden(tester, 'library_fresh_picks_section');
  });
}
