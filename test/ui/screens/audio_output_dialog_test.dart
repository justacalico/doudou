import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/audio_output_service.dart';
import 'package:doudou/ui/screens/Settings/audio_output_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeInvoker {
  final calls = <String>[];
  List<dynamic> devicesResponse = const [];
  bool selectResponse = true;

  Future<T?> call<T>(String method, [dynamic arguments]) async {
    calls.add(method);
    return switch (method) {
      'getDevices' => devicesResponse as T?,
      'selectDevice' => selectResponse as T?,
      _ => null,
    };
  }
}

Widget _wrap(Widget child) {
  return GetMaterialApp(
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeInvoker invoker;

  AudioOutputDialog dialog() => AudioOutputDialog(
        service: AudioOutputService(
          invoke: invoker.call,
          supported: () => true,
        ),
      );

  setUp(() => invoker = _FakeInvoker());

  testWidgets('lists the routes reported by the platform', (tester) async {
    invoker.devicesResponse = [
      {'id': 'r1', 'name': 'Phone speaker', 'kind': 'speaker', 'selected': true},
      {'id': 'r2', 'name': 'WH-1000XM5', 'kind': 'bluetooth'},
    ];

    await tester.pumpWidget(_wrap(dialog()));
    await tester.pumpAndSettle();

    expect(find.text('Phone speaker'), findsOneWidget);
    expect(find.text('WH-1000XM5'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a route selects it and reloads the list',
      (tester) async {
    invoker.devicesResponse = [
      {'id': 'r1', 'name': 'Phone speaker', 'kind': 'speaker', 'selected': true},
      {'id': 'r2', 'name': 'WH-1000XM5', 'kind': 'bluetooth', 'selected': false},
    ];

    await tester.pumpWidget(_wrap(dialog()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WH-1000XM5'));
    await tester.pumpAndSettle();

    expect(invoker.calls.where((c) => c == 'selectDevice'), hasLength(1));
    // a successful select reloads the route list
    expect(invoker.calls.where((c) => c == 'getDevices'), hasLength(2));
  });

  testWidgets('shows the empty state when no routes are reported',
      (tester) async {
    await tester.pumpWidget(_wrap(dialog()));
    await tester.pumpAndSettle();

    expect(find.text('No output devices found'), findsOneWidget);
  });

  testWidgets('non selectable routes open the system picker instead',
      (tester) async {
    var pickerCalls = 0;
    final service = AudioOutputService(
      supported: () => true,
      invoke: <T>(String method, [dynamic arguments]) async {
        if (method == 'showSystemPicker') {
          pickerCalls++;
          return true as T?;
        }
        if (method == 'getDevices') {
          return [
            {'id': 'ap1', 'name': 'Living Room', 'kind': 'airplay', 'selectable': false},
          ] as T?;
        }
        return null;
      },
    );

    await tester.pumpWidget(_wrap(AudioOutputDialog(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Living Room'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
  });
}
