import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/widgets/home_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeEmptyState', () {
    Widget buildSubject({
      required bool hasServer,
      VoidCallback? onAction,
      Locale locale = const Locale('en', 'AU'),
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('en', 'AU'),
          Locale('zh'),
          Locale('ru'),
        ],
        home: Scaffold(
          body: HomeEmptyState(
            hasServer: hasServer,
            onAction: onAction ?? () {},
          ),
        ),
      );
    }

    testWidgets('shows the hint and a browse action when a server exists',
        (tester) async {
      await tester.pumpWidget(buildSubject(hasServer: true));

      expect(find.byIcon(Icons.library_music_outlined), findsOneWidget);
      expect(
        find.text('Add music to your library to see it here, mate'),
        findsOneWidget,
      );
      expect(find.text('Browse library'), findsOneWidget);
      expect(find.text('Add server'), findsNothing);
    });

    testWidgets('offers add-server action when no server is configured',
        (tester) async {
      await tester.pumpWidget(buildSubject(hasServer: false));

      expect(find.text('Add server'), findsOneWidget);
      expect(find.text('Browse library'), findsNothing);
    });

    testWidgets('tapping the action fires the callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(hasServer: true, onAction: () => tapped = true),
      );

      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders localized strings for zh', (tester) async {
      await tester.pumpWidget(
        buildSubject(hasServer: false, locale: const Locale('zh')),
      );

      expect(find.text('浏览音乐库'), findsNothing);
      expect(find.text('添加服务器'), findsOneWidget);
    });
  });
}
