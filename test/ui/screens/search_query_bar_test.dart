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
  final submitted = <String>[];

  @override
  Future<void> submitSearch(String value) async {
    submitted.add(value);
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
    testWidgets('shows the current query inside the bar', (tester) async {
      controller.queryEditingController.text = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));

      expect(find.text('white rabbit'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('typing and submitting resubmits the search in place',
        (tester) async {
      controller.queryEditingController.text = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));
      await tester.enterText(find.byType(TextField), 'green rabbit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(controller.submitted, ['green rabbit']);
    });

    testWidgets('renders the query with the titleMedium text style',
        (tester) async {
      controller.queryEditingController.text = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));

      final context = tester.element(find.byType(TextField));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontSize,
          Theme.of(context).textTheme.titleMedium?.fontSize);
    });

    testWidgets('clear button empties the query field', (tester) async {
      controller.queryEditingController.text = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.queryEditingController.text, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(controller.submitted, isEmpty);
    });
  });
}
