import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/widgets/home_quick_action_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeQuickActionCards', () {
    Widget buildSubject({
      bool isYouTubeMusic = true,
      int shuffleCount = 0,
      int favoriteCount = 0,
      int downloadCount = 0,
      VoidCallback? onStartSupermix,
      VoidCallback? onShuffleAll,
      VoidCallback? onShuffleFavorites,
      VoidCallback? onShuffleDownloads,
    }) {
      return MaterialApp(
        locale: const Locale('en', 'AU'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeQuickActionCards(
            isYouTubeMusic: isYouTubeMusic,
            shuffleCount: shuffleCount,
            favoriteCount: favoriteCount,
            downloadCount: downloadCount,
            onStartSupermix: onStartSupermix ?? () {},
            onShuffleAll: onShuffleAll ?? () {},
            onShuffleFavorites: onShuffleFavorites ?? () {},
            onShuffleDownloads: onShuffleDownloads ?? () {},
          ),
        ),
      );
    }

    testWidgets('YouTube Music home shows Supermix but no Start radio card',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Supermix'), findsOneWidget);
      expect(find.text('Start radio'), findsNothing);
      expect(find.byIcon(Icons.radio), findsNothing);
    });

    testWidgets('tapping Supermix fires its callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(onStartSupermix: () => tapped = true),
      );

      await tester.tap(find.text('Supermix'));
      expect(tapped, isTrue);
    });

    testWidgets('non-YouTube Music home shows Shuffle all instead of Supermix',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(isYouTubeMusic: false, shuffleCount: 42),
      );

      expect(find.text('Shuffle all'), findsOneWidget);
      expect(find.text('42 songs'), findsOneWidget);
      expect(find.text('Supermix'), findsNothing);
      expect(find.text('Start radio'), findsNothing);
    });

    testWidgets('favourites and downloads cards appear when counts are set',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(favoriteCount: 3, downloadCount: 7),
      );

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('7 songs'), findsOneWidget);
    });

    testWidgets('renders nothing when no cards apply', (tester) async {
      await tester.pumpWidget(buildSubject(isYouTubeMusic: false));

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
