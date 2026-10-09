import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/mcp/mcp_http_server.dart';
import 'package:doudou/mcp/mcp_server.dart';
import 'package:doudou/services/mcp_server_service.dart';
import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:doudou/ui/widgets/custom_switch.dart';
import 'package:doudou/ui/widgets/mcp_server_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../services/mcp_server_service_test.dart' show FakeMcpAppBridge;

/// A bind-free stand-in: widget tests run in a fake-async zone where real
/// socket binds cannot complete, and a socket finishing late would leak past
/// tearDown and hang the suite.
class _FakeHttpServer extends McpHttpServer {
  _FakeHttpServer(super.engine);

  int _port = 0;
  bool _running = false;

  @override
  int get port => _port;

  @override
  Future<void> start({required int port, InternetAddress? host}) async {
    _port = port;
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }
}

/// Preference writes complete immediately so nothing real-I/O is left
/// dangling in the fake-async zone.
class _MockPrefsBox extends Mock implements Box {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box box;
  late Box prefsBox;
  late McpServerService service;

  setUpAll(() {
    // ThemeController builds a google_fonts theme; tests have no network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    Hive.init(
        '/tmp/doudou_mcp_dialog_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox('AppPrefs_mcp_dialog_test');
    await Hive.openBox('AppPrefs');
    prefsBox = _MockPrefsBox();
    when(() => prefsBox.put(any(), any())).thenAnswer((_) async {});
    service = McpServerService(
      prefs: prefsBox,
      bridge: FakeMcpAppBridge(),
      supported: true,
      httpFactory: _FakeHttpServer.new,
    );
    Get.put<McpServerService>(service);
    // CustSwitch reads the registered ThemeController.
    Get.put(ThemeController());
  });

  tearDown(() async {
    await service.stop();
    Get.reset();
    await box.clear();
    await box.deleteFromDisk();
    await Hive.close();
  });

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      );

  testWidgets('shows the title and description', (tester) async {
    await tester.pumpWidget(app(const McpServerDialog()));
    await tester.pumpAndSettle();

    expect(find.text('MCP server'), findsOneWidget);
    expect(find.textContaining('Model Context Protocol'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
  });

  testWidgets('switch enables the service and shows the address',
      (tester) async {
    await tester.pumpWidget(app(const McpServerDialog()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CustSwitch));
    await tester.pumpAndSettle();

    expect(service.enabled.value, isTrue);
    expect(service.running.value, isTrue);
    expect(find.textContaining('http://127.0.0.1:'), findsOneWidget);
  });

  testWidgets('rejects an invalid port', (tester) async {
    service.enabled.value = true;
    await tester.pumpWidget(app(const McpServerDialog()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '80');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Enter a port between 1024 and 65535'),
        findsOneWidget);
  });
}
