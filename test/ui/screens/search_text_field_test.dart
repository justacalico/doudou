import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/design/doudou_theme.dart';
import 'package:doudou/ui/screens/Search/components/search_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildSubject({
  TextEditingController? controller,
  void Function(String)? onChanged,
  void Function(String)? onSubmitted,
  VoidCallback? onClear,
}) {
  final textController = controller ?? TextEditingController();
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
      body: SearchTextField(
        controller: textController,
        onChanged: onChanged ?? (_) {},
        onSubmitted: onSubmitted ?? (_) {},
        onClear: onClear ?? () {},
      ),
    ),
  );
}

InputDecoration effectiveDecoration(WidgetTester tester) {
  // TextField merges the widget decoration with the ambient
  // inputDecorationTheme before handing it to InputDecorator, so the
  // decoration stored on InputDecorator is the effective one.
  return tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
}

void main() {
  group('SearchTextField', () {
    testWidgets('does not paint a second box from the themed input border',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      // DoudouTheme defines filled OutlineInputBorders for every state. If
      // the search decoration only sets `border: InputBorder.none`, the
      // themed enabled/focused borders and fill still render as a second
      // rounded box inside the search bar container.
      await tester.pumpWidget(buildSubject(controller: controller));

      final decoration = effectiveDecoration(tester);
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(decoration.filled, isFalse);
      expect(decoration.hoverColor, Colors.transparent);
      expect(decoration.focusColor, Colors.transparent);
    });

    testWidgets('stays borderless after the field gains focus',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildSubject(controller: controller));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final decorator =
          tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.isFocused, isTrue);
      expect(effectiveDecoration(tester).focusedBorder, InputBorder.none);
    });

    testWidgets('shows the localized hint text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildSubject(controller: controller));

      expect(find.text('Songs, Playlist, Album or Artist'), findsOneWidget);
    });

    testWidgets('wires onChanged and onSubmitted through', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changed = <String>[];
      final submitted = <String>[];

      await tester.pumpWidget(buildSubject(
        controller: controller,
        onChanged: changed.add,
        onSubmitted: submitted.add,
      ));

      await tester.enterText(find.byType(TextField), 'doudou');
      expect(changed, ['doudou']);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, ['doudou']);
    });
  });
}
