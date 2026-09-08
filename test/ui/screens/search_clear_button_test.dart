import 'package:doudou/ui/screens/Search/components/search_clear_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchClearButton', () {
    Widget buildSubject(
      TextEditingController controller, {
      VoidCallback? onPressed,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            decoration: InputDecoration(
              suffix: SearchClearButton(
                controller: controller,
                onPressed: onPressed ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is hidden while the field is empty', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildSubject(controller));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('appears once text is entered and hides after clearing',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildSubject(controller));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('reacts to programmatic text changes', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildSubject(controller));
      controller.text = 'query';
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      controller.text = '';
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      final controller = TextEditingController(text: 'something');
      addTearDown(controller.dispose);
      var tapped = false;

      await tester.pumpWidget(
        buildSubject(controller, onPressed: () => tapped = true),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(tapped, isTrue);
    });
  });
}
