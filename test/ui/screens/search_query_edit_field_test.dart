import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_theme.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Search/components/search_query_edit_field.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

Widget _buildSubject(
  _StubResultController controller, {
  TextStyle? style,
  TextAlign textAlign = TextAlign.start,
}) {
  return MaterialApp(
    theme: DoudouTheme.dark(accent: kDoudouPurple),
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SearchQueryEditField(
        controller: controller,
        style: style,
        textAlign: textAlign,
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

  group('SearchQueryEditField', () {
    testWidgets('shows the current query and submits typed edits',
        (tester) async {
      controller.queryEditingController.text = 'white rabbit';

      await tester.pumpWidget(_buildSubject(controller));

      expect(find.text('white rabbit'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'green rabbit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(controller.submitted, ['green rabbit']);
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

    testWidgets('forwards text style and alignment to the field',
        (tester) async {
      const style = TextStyle(fontSize: 22, fontStyle: FontStyle.italic);

      await tester.pumpWidget(_buildSubject(
        controller,
        style: style,
        textAlign: TextAlign.center,
      ));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontSize, 22);
      expect(field.style?.fontStyle, FontStyle.italic);
      expect(field.textAlign, TextAlign.center);
    });
  });
}
