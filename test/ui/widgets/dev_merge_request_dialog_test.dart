import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/widgets/dev_merge_request_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mrId = '42';
  const mrUrl = 'https://gitlab.com/Openlyst/doudou/-/merge_requests/42';

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget app(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  group('DevMergeRequestWrapper', () {
    testWidgets('shows the dialog when a merge request id is baked in',
        (tester) async {
      await tester.pumpWidget(app(const DevMergeRequestWrapper(
        mergeRequestId: mrId,
        mergeRequestUrl: mrUrl,
        child: SizedBox.expand(),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(DevMergeRequestDialog), findsOneWidget);
      expect(find.text('Development merge request'), findsOneWidget);
      expect(find.textContaining('!$mrId'), findsOneWidget);
      expect(find.textContaining(mrUrl), findsOneWidget);
    });

    testWidgets('stays silent without a merge request id', (tester) async {
      await tester.pumpWidget(
        app(const DevMergeRequestWrapper(child: SizedBox.expand())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DevMergeRequestDialog), findsNothing);
    });

    testWidgets('closes on the close button', (tester) async {
      await tester.pumpWidget(app(const DevMergeRequestWrapper(
        mergeRequestId: mrId,
        mergeRequestUrl: mrUrl,
        child: SizedBox.expand(),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(DevMergeRequestDialog), findsNothing);
    });

    testWidgets('copy button puts the merge request url on the clipboard',
        (tester) async {
      await tester.pumpWidget(app(const DevMergeRequestWrapper(
        mergeRequestId: mrId,
        mergeRequestUrl: mrUrl,
        child: SizedBox.expand(),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(clipboardText, mrUrl);
    });
  });

  group('DevMergeRequestDialog', () {
    testWidgets('hides url actions when the url is missing', (tester) async {
      await tester.pumpWidget(app(const Scaffold(
        body: DevMergeRequestDialog(
          mergeRequestId: mrId,
          mergeRequestUrl: '',
        ),
      )));

      expect(find.text('Copy'), findsNothing);
      expect(find.text('Open'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(
        find.textContaining('URL is not available'),
        findsOneWidget,
      );
    });

    testWidgets('hides url actions when the url is not openable',
        (tester) async {
      await tester.pumpWidget(app(const Scaffold(
        body: DevMergeRequestDialog(
          mergeRequestId: mrId,
          mergeRequestUrl: 'not-a-url',
        ),
      )));

      expect(find.text('Copy'), findsNothing);
      expect(find.text('Open'), findsNothing);
      expect(find.textContaining('URL is not available'), findsOneWidget);
    });
  });
}
