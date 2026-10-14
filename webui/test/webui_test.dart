import 'package:doudou_server_webui/api.dart';
import 'package:doudou_server_webui/token_store.dart';
import 'package:doudou_server_webui/main.dart';
import 'package:doudou_server_webui/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends WebuiApi {
  FakeApi({required this.stateResult}) : super(tokenStore: MemoryTokenStore());

  ServerState stateResult;
  bool tokenCheck = true;
  String? loggedInWith;
  String? setupWith;
  bool loggedOut = false;
  List<HostedBackend> backendList = [];
  List<SyncBox> boxList = [];

  @override
  Future<ServerState> state() async => stateResult;

  @override
  Future<bool> tokenValid() async => tokenCheck;

  @override
  Future<void> login(String password) async {
    loggedInWith = password;
    tokenStore.write('session');
  }

  @override
  Future<void> setup(String password) async {
    setupWith = password;
    tokenStore.write('session');
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    tokenStore.clear();
  }

  @override
  Future<List<HostedBackend>> backends() async => backendList;

  @override
  Future<List<SyncBox>> boxes() async => boxList;

  @override
  Future<LogPage> logs(int after) async =>
      LogPage(entries: const [], latest: 0);
}

void main() {
  testWidgets('setup asks for the password twice and claims the server', (
    tester,
  ) async {
    final api = FakeApi(stateResult: ServerState(setupRequired: true));
    await tester.pumpWidget(DoudouServerApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Set password'), findsOneWidget);
    expect(find.text('Repeat password'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      'pw1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Repeat password'),
      'pw2',
    );
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(api.setupWith, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Repeat password'),
      'pw1',
    );
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    expect(api.setupWith, 'pw1');
    expect(find.text('Backends'), findsOneWidget);
  });

  testWidgets('login calls the api and lands on the dashboard', (tester) async {
    final api = FakeApi(stateResult: ServerState(setupRequired: false))
      ..backendList = [
        HostedBackend(
          id: 1,
          name: 'Home Jellyfin',
          type: 'jellyfin',
          serverUrl: 'http://jf.local:8096',
        ),
        HostedBackend(id: 2, name: 'YTM', type: 'youtubeMusic'),
      ]
      ..boxList = [SyncBox(name: 'LIBFAV', rev: 3, keys: 42)];
    await tester.pumpWidget(DoudouServerApp(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(api.loggedInWith, 'hunter2');
    expect(find.text('Home Jellyfin'), findsOneWidget);
    expect(find.text('YTM'), findsOneWidget);
    expect(find.text('LIBFAV'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);

    // the log poll timer has to go or the test ends with it pending
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a stored token skips the login screen and logout returns', (
    tester,
  ) async {
    final api = FakeApi(stateResult: ServerState(setupRequired: false));
    api.tokenStore.write('session');
    await tester.pumpWidget(DoudouServerApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Backends'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(api.loggedOut, isTrue);
    expect(find.text('Log in'), findsOneWidget);
  });

  test('models parse the wire maps', () {
    final backend = HostedBackend.fromJson({
      'id': 4,
      'name': 'Navidrome',
      'type': 'subsonic',
      'serverUrl': 'http://n.local',
    });
    expect(backend.id, 4);
    expect(backend.needsUrl, isTrue);
    expect(HostedBackend.typeLabel('subsonic'), contains('Subsonic'));

    final entry = LogEntry.fromJson({
      'seq': 9,
      'ts': 1000,
      'level': 'warn',
      'msg': 'hello',
    });
    expect(entry.seq, 9);
    expect(entry.level, 'warn');
  });
}
