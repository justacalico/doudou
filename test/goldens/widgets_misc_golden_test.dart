import 'dart:io';

import 'package:doudou/models/durationstate.dart';
import 'package:doudou/ui/widgets/common_dialog_widget.dart';
import 'package:doudou/ui/widgets/custom_button.dart';
import 'package:doudou/ui/widgets/custom_switch.dart';
import 'package:doudou/ui/widgets/home_empty_state.dart';
import 'package:doudou/ui/widgets/home_quick_action_cards.dart';
import 'package:doudou/ui/widgets/library_bookmark_icon.dart';
import 'package:doudou/ui/widgets/loader.dart';
import 'package:doudou/ui/widgets/mini_player_progress_bar.dart';
import 'package:doudou/ui/widgets/modified_text_field.dart';
import 'package:doudou/ui/widgets/nightly_build_badge.dart';
import 'package:doudou/ui/widgets/page_title.dart';
import 'package:doudou/ui/widgets/scroll_to_hide.dart';
import 'package:doudou/services/tv_service.dart';
import 'package:doudou/ui/widgets/tv_focus_highlight.dart';
import 'package:doudou/ui/widgets/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_misc_');
    Hive.init(hiveDir.path);
    await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await installGoldenDeps();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('buttons', (tester) async {
    await pumpGolden(
      tester,
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProceedButton(buttonText: 'Save changes', onPressed: () {}),
          const SizedBox(height: 16),
          ProceedButton(buttonText: 'Disabled', onPressed: null),
          const SizedBox(height: 16),
          const CancelButton(),
        ],
      ),
      size: const Size(400, 300),
    );
    await expectGolden(tester, 'buttons');
  });

  testWidgets('switch on and off', (tester) async {
    await pumpGolden(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustSwitch(value: true, onChanged: (_) {}),
          const SizedBox(width: 32),
          CustSwitch(value: false, onChanged: (_) {}),
        ],
      ),
      size: const Size(300, 120),
    );
    await expectGolden(tester, 'switch');
  });

  testWidgets('loading indicator', (tester) async {
    await pumpGolden(
      tester,
      const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(),
            SizedBox(width: 24),
            LoadingIndicator(value: 0.6, dimension: 48),
          ],
        ),
      ),
      size: const Size(300, 150),
      settle: false,
    );
    await expectGolden(tester, 'loading_indicator');
  });

  testWidgets('page title', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: PageTitle('Library'),
        ),
      ),
      size: const Size(600, 160),
    );
    await expectGolden(tester, 'page_title');
  });

  testWidgets('nightly build badge', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: NightlyBuildBadge(isNightly: true, label: 'nightly')),
      size: const Size(300, 120),
    );
    await expectGolden(tester, 'nightly_badge');
  });

  testWidgets('library bookmark icon', (tester) async {
    await pumpGolden(
      tester,
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LibraryBookmarkIcon(isBookmarked: true, size: 32),
          SizedBox(width: 24),
          LibraryBookmarkIcon(isBookmarked: false, size: 32),
        ],
      ),
      size: const Size(300, 120),
    );
    await expectGolden(tester, 'library_bookmark_icon');
  });

  testWidgets('home empty state with server', (tester) async {
    await pumpGolden(
      tester,
      Center(child: HomeEmptyState(hasServer: true, onAction: () {})),
      size: const Size(700, 400),
    );
    await expectGolden(tester, 'home_empty_state_server');
  });

  testWidgets('home empty state without server', (tester) async {
    await pumpGolden(
      tester,
      Center(child: HomeEmptyState(hasServer: false, onAction: () {})),
      size: const Size(700, 400),
    );
    await expectGolden(tester, 'home_empty_state_no_server');
  });

  testWidgets('home quick action cards', (tester) async {
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: HomeQuickActionCards(
          isYouTubeMusic: true,
          shuffleCount: 128,
          favoriteCount: 42,
          downloadCount: 17,
          onStartSupermix: () {},
          onShuffleAll: () {},
          onShuffleFavorites: () {},
          onShuffleDownloads: () {},
        ),
      ),
      size: const Size(1100, 300),
    );
    await expectGolden(tester, 'home_quick_action_cards');
  });

  testWidgets('scroll to hide', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.bottomCenter,
        child: ScrollToHideWidget(
          isVisible: true,
          child: ColoredBox(
            color: Color(0xFF333340),
            child: Center(child: Text('Bottom bar content')),
          ),
        ),
      ),
      size: const Size(600, 200),
    );
    await expectGolden(tester, 'scroll_to_hide');
  });

  testWidgets('window controls', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.topRight,
        child: WindowControls(),
      ),
      size: const Size(400, 120),
    );
    await expectGolden(tester, 'window_controls');
  });

  testWidgets('mini player progress bar', (tester) async {
    await pumpGolden(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: MiniPlayerProgressBar(
          progressBarStatus: ProgressBarState(
            current: Duration(minutes: 1, seconds: 12),
            buffered: Duration(minutes: 2),
            total: Duration(minutes: 3, seconds: 24),
          ),
          progressBarColor: goldenAccent,
        ),
      ),
      size: const Size(800, 60),
    );
    await expectGolden(tester, 'mini_player_progress_bar');
  });

  testWidgets('common dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(
        child: CommonDialog(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Dialog body content goes here'),
          ),
        ),
      ),
      size: const Size(900, 500),
      settle: false,
    );
    await expectGolden(tester, 'common_dialog');
  });

  testWidgets('modified text field', (tester) async {
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(24),
        child: ModifiedTextField(
          controller: TextEditingController(text: 'Search query text'),
          decoration: const InputDecoration(hintText: 'Hint text'),
        ),
      ),
      size: const Size(600, 160),
    );
    await expectGolden(tester, 'modified_text_field');
  });

  testWidgets('tv focus highlight', (tester) async {
    Get.find<TvService>().isTV.value = true;
    await pumpGolden(
      tester,
      Center(
        child: TvFocusHighlight(
          autofocus: true,
          child: Container(
            width: 200,
            height: 100,
            color: const Color(0xFF333340),
            child: const Center(child: Text('Focusable tile')),
          ),
        ),
      ),
      size: const Size(400, 250),
    );
    await expectGolden(tester, 'tv_focus_highlight');
  });
}
