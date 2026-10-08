import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_theme.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Search/components/search_query_bar.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../fakes.dart';

class _FakeHomeScreenController extends HomeScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void whenHomeScreenOnTop() {}
}

class _StubResultController extends SearchResultScreenController {
  int editTaps = 0;

  @override
  void editQuery() {
    editTaps++;
  }
}

Widget _buildSubject(_StubResultController controller) {
  return MaterialApp(
    theme: DoudouTheme.dark(accent: kDoudouPurple),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: SearchQueryBar(controller: controller),
        ),
      ),
    ),
  );
}

void main() {
  late _StubResultController controller;

  setUp(() {
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<HomeScreenController>(_FakeHomeScreenController());
    controller = _StubResultController();
  });

  tearDown(() {
    controller.onClose();
    Get.delete<HomeScreenController>(force: true);
    Get.delete<MusicServices>(force: true);
  });

  group('SearchQueryBar', () {
    testWidgets('shows the current query with search and edit icons',
        (tester) async {
      controller.queryString.value = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));

      expect(find.text('white rabbit'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('updates when the query changes', (tester) async {
      controller.queryString.value = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));
      controller.queryString.value = 'green rabbit';
      await tester.pump();

      expect(find.text('green rabbit'), findsOneWidget);
      expect(find.text('white rabbit'), findsNothing);
    });

    testWidgets('tapping the bar asks to edit the query', (tester) async {
      controller.queryString.value = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));
      await tester.tap(find.byType(SearchQueryBar));

      expect(controller.editTaps, 1);
    });
  });
}
