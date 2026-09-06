import 'package:doudou/ui/widgets/nightly_build_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NightlyBuildBadge', () {
    testWidgets('shows the icon and label for nightly builds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NightlyBuildBadge(
              isNightly: true,
              label: 'Nightly build',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.nights_stay), findsOneWidget);
      expect(find.text('Nightly build'), findsOneWidget);
    });

    testWidgets('renders nothing for non-nightly builds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NightlyBuildBadge(
              isNightly: false,
              label: 'Nightly build',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.nights_stay), findsNothing);
      expect(find.text('Nightly build'), findsNothing);
    });
  });
}
