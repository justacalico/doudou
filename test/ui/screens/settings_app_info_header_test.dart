import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/screens/Settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('AppInfoHeader shows the nightly build badge', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppInfoHeader(version: '22.0.0', isNightly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.nights_stay), findsOneWidget);
    expect(find.text('Nightly build'), findsOneWidget);
  });

  testWidgets('AppInfoHeader hides the nightly build badge', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppInfoHeader(version: '22.0.0', isNightly: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.nights_stay), findsNothing);
    expect(find.text('Nightly build'), findsNothing);
  });
}
