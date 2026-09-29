import 'package:doudou_landing/app.dart';
import 'package:doudou_landing/links.dart';
import 'package:doudou_landing/widgets/download_section.dart';
import 'package:doudou_landing/widgets/reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpSite(
  WidgetTester tester, {
  Size size = const Size(1600, 4800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DoudouSite());
  await tester.pumpAndSettle();
}

void main() {
  group('links', () {
    test('every outbound link is https and on a known host', () {
      for (final url in [
        Links.download,
        Links.repo,
        Links.releases,
        Links.issues,
        Links.license,
        Links.harmonyMusic,
      ]) {
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https');
        expect(
          uri.host,
          isIn(['openlyst.ink', 'gitlab.com', 'github.com']),
        );
      }
    });
  });

  group('landing page', () {
    testWidgets('renders hero copy and calls to action', (tester) async {
      await pumpSite(tester);
      expect(find.textContaining('Every song you have.'), findsOneWidget);
      expect(find.textContaining('On every screen you own.'), findsOneWidget);
      expect(find.text('Download'), findsWidgets);
      expect(find.text('Source on GitLab'), findsOneWidget);
    });

    testWidgets('lists every backend and every platform', (tester) async {
      await pumpSite(tester);
      for (final b in [
        'Subsonic',
        'OpenSubsonic',
        'Jellyfin',
        'Plex',
        'YouTube Music',
      ]) {
        expect(find.text(b), findsWidgets, reason: b);
      }
      for (final p in DownloadSection.platforms) {
        expect(find.text(p), findsWidgets, reason: p);
      }
    });

    testWidgets('shows the feature set and spec sheet', (tester) async {
      await pumpSite(tester);
      expect(find.text('Everything a player should do.'), findsOneWidget);
      expect(find.text('Offline downloads'), findsOneWidget);
      expect(find.text('Gapless playback'), findsOneWidget);
      expect(find.textContaining('GPL-3.0'), findsWidgets);
      expect(find.text('gitlab.com/Openlyst/doudou'), findsOneWidget);
    });

    testWidgets('platform chips open the download page', (tester) async {
      final opened = <String>[];
      final real = Links.open;
      Links.open = (url) async => opened.add(url);
      addTearDown(() => Links.open = real);

      await pumpSite(tester);
      await tester.ensureVisible(find.text('Linux'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linux'));
      expect(opened, [Links.download]);
    });

    testWidgets('faq rows expand to show their answer', (tester) async {
      await pumpSite(tester);
      final answer = find.byType(AnimatedCrossFade).first;
      expect(tester.getSize(answer).height, lessThan(2));

      await tester.ensureVisible(find.text('Can I listen away from home?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Can I listen away from home?'));
      await tester.pumpAndSettle();
      expect(tester.getSize(answer).height, greaterThan(2));
    });

    for (final w in [320.0, 375.0, 414.0, 768.0]) {
      testWidgets('lays out without overflow at ${w.round()}px', (
        tester,
      ) async {
        await pumpSite(tester, size: Size(w, 6000));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Every song you have.'), findsOneWidget);
      });
    }

    testWidgets('Reveal renders instantly under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Reveal(child: Text('visible')),
          ),
        ),
      );
      await tester.pump();
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });
  });
}
