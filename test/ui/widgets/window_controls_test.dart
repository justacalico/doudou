import 'package:doudou/ui/widgets/window_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowControls', () {
    Widget buildSubject() {
      return const MaterialApp(
        home: Scaffold(
          body: WindowControls(),
        ),
      );
    }

    BoxDecoration buttonDecoration(WidgetTester tester, IconData icon) {
      final containers = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(Container),
      );
      final container = containers
          .evaluate()
          .map((e) => e.widget as Container)
          .firstWhere((c) => c.decoration != null);
      return container.decoration! as BoxDecoration;
    }

    testWidgets('close button hover shows a circular background',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      var decoration = buttonDecoration(tester, Icons.close);
      expect(decoration.color, Colors.transparent);

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byIcon(Icons.close)));
      await tester.pump();

      decoration = buttonDecoration(tester, Icons.close);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, const Color(0xFFe81123));
    });

    testWidgets('hover background clears when the pointer leaves',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      final center = tester.getCenter(find.byIcon(Icons.close));
      await gesture.moveTo(center);
      await tester.pump();
      expect(buttonDecoration(tester, Icons.close).shape, BoxShape.circle);

      await gesture.moveTo(center + const Offset(0, 100));
      await tester.pump();
      expect(
        buttonDecoration(tester, Icons.close).color,
        Colors.transparent,
      );
    });
  });
}
