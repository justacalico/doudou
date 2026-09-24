import 'package:doudou/models/audio_output_device.dart';
import 'package:doudou/services/audio_output_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInvoker {
  final calls = <String>[];
  final args = <dynamic>[];
  Object? response;
  Object? error;

  Future<T?> call<T>(String method, [dynamic arguments]) async {
    calls.add(method);
    args.add(arguments);
    if (error != null) throw error!;
    return response as T?;
  }
}

AudioOutputService _service(
  _FakeInvoker invoker, {
  bool supported = true,
}) {
  return AudioOutputService(
    invoke: invoker.call,
    supported: () => supported,
  );
}

void main() {
  late _FakeInvoker invoker;

  setUp(() => invoker = _FakeInvoker());

  test('devices parses the platform route list', () async {
    invoker.response = [
      {'id': 'r1', 'name': 'Phone speaker', 'kind': 'speaker', 'selected': true, 'selectable': true},
      {'id': 'r2', 'name': 'WH-1000XM5', 'kind': 'bluetooth'},
    ];

    final devices = await _service(invoker).devices();

    expect(invoker.calls, ['getDevices']);
    expect(devices, [
      const AudioOutputDevice(
        id: 'r1',
        name: 'Phone speaker',
        kind: AudioOutputKind.speaker,
        selected: true,
      ),
      const AudioOutputDevice(
        id: 'r2',
        name: 'WH-1000XM5',
        kind: AudioOutputKind.bluetooth,
      ),
    ]);
  });

  test('devices maps unknown kinds to other', () async {
    invoker.response = [
      {'id': 'r1', 'name': 'Mystery box', 'kind': 'wormhole'},
      {'id': 'r2', 'name': 'No kind'},
    ];

    final devices = await _service(invoker).devices();

    expect(devices.map((d) => d.kind),
        [AudioOutputKind.other, AudioOutputKind.other]);
  });

  test('devices skips non map entries', () async {
    invoker.response = [
      'junk',
      {'id': 'r1', 'name': 'Speaker', 'kind': 'speaker'},
    ];

    final devices = await _service(invoker).devices();
    expect(devices.single.name, 'Speaker');
  });

  test('devices returns empty when the platform is unsupported', () async {
    final devices = await _service(invoker, supported: false).devices();
    expect(devices, isEmpty);
    expect(invoker.calls, isEmpty);
  });

  test('devices returns empty on missing plugin and platform errors',
      () async {
    invoker.error = MissingPluginException();
    expect(await _service(invoker).devices(), isEmpty);

    invoker = _FakeInvoker()..error = PlatformException(code: 'x');
    expect(await _service(invoker).devices(), isEmpty);
  });

  test('select passes the route id to the platform', () async {
    invoker.response = true;

    final ok = await _service(invoker).select(
      const AudioOutputDevice(id: 'r2', name: 'Headphones'),
    );

    expect(ok, isTrue);
    expect(invoker.calls, ['selectDevice']);
    expect(invoker.args.single, {'id': 'r2'});
  });

  test('select refuses non selectable routes without a platform call',
      () async {
    final ok = await _service(invoker).select(
      const AudioOutputDevice(
        id: 'r1',
        name: 'AirPlay',
        selectable: false,
      ),
    );

    expect(ok, isFalse);
    expect(invoker.calls, isEmpty);
  });

  test('select returns false when the platform call fails', () async {
    invoker.error = PlatformException(code: 'nope');
    final ok = await _service(invoker).select(
      const AudioOutputDevice(id: 'r1', name: 'Speaker'),
    );
    expect(ok, isFalse);
  });

  test('showSystemPicker forwards to the platform', () async {
    invoker.response = true;
    expect(await _service(invoker).showSystemPicker(), isTrue);
    expect(invoker.calls, ['showSystemPicker']);
  });

  test('showSystemPicker returns false on missing plugin', () async {
    invoker.error = MissingPluginException();
    expect(await _service(invoker).showSystemPicker(), isFalse);
  });
}
