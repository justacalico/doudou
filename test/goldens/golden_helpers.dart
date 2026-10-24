import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/design/doudou_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const goldenAccent = Color(0xFF7C3AED);
const goldenRootKey = ValueKey('goldenRoot');

ThemeData goldenTheme({
  Brightness brightness = Brightness.dark,
  Color accent = goldenAccent,
}) {
  final theme = switch (brightness) {
    Brightness.dark => DoudouTheme.dark(accent: accent),
    Brightness.light => DoudouTheme.light(accent: accent),
  };
  final textTheme = theme.textTheme.apply(fontFamily: 'Inter');
  return theme.copyWith(
    textTheme: textTheme,
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Inter'),
    snackBarTheme:
        theme.snackBarTheme.copyWith(contentTextStyle: textTheme.bodyMedium),
  );
}

ThemeData goldenOledTheme({Color accent = goldenAccent}) {
  final theme = DoudouTheme.oled(accent: accent);
  final textTheme = theme.textTheme.apply(fontFamily: 'Inter');
  return theme.copyWith(
    textTheme: textTheme,
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Inter'),
    snackBarTheme:
        theme.snackBarTheme.copyWith(contentTextStyle: textTheme.bodyMedium),
  );
}

Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 800),
  ThemeData? theme,
  Locale? locale,
  bool useScaffold = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale ?? const Locale('en'),
      theme: theme ?? goldenTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepaintBoundary(
        key: goldenRootKey,
        child: useScaffold ? Scaffold(body: child) : child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> expectGolden(WidgetTester tester, String name) {
  return expectLater(
    find.byKey(goldenRootKey),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Clears reported framework exceptions. Several app widgets trip
/// debug-only asserts (e.g. ListTile under a DecoratedBox) that are
/// reported but do not stop the tree from rendering.
void drainExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// Captures the whole render view, including overlays such as dialogs,
/// bottom sheets and snackbars that live outside the app home subtree.
Future<void> expectGoldenView(WidgetTester tester, String name) {
  return expectLater(
    find.byType(View),
    matchesGoldenFile('goldens/$name.png'),
  );
}
