import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart' show TolerantGoldenComparator;

Future<Uint8List> _png({ui.Rect? spot}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 20, 20),
    ui.Paint()..color = const ui.Color(0xFF112233),
  );
  if (spot != null) {
    canvas.drawRect(
      spot,
      ui.Paint()
        ..color = const ui.Color(0xFFDD0000)
        ..isAntiAlias = false,
    );
  }
  final image = await recorder.endRecording().toImage(20, 20);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  late Directory dir;
  late TolerantGoldenComparator comparator;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('doudou_comparator_');
    comparator =
        TolerantGoldenComparator(Uri.file('${dir.path}/fake_test.dart'));
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('accepts identical images', () async {
    final golden = await _png();
    File('${dir.path}/same.png').writeAsBytesSync(golden);

    expect(await comparator.compare(await _png(), Uri.parse('same.png')),
        isTrue);
  });

  test('accepts a diff within tolerance', () async {
    File('${dir.path}/golden.png').writeAsBytesSync(await _png());
    final variant = await _png(spot: const ui.Rect.fromLTWH(0, 0, 1, 1));

    expect(
        await comparator.compare(variant, Uri.parse('golden.png')), isTrue);
  });

  test('rejects a diff beyond tolerance', () async {
    File('${dir.path}/golden.png').writeAsBytesSync(await _png());
    final variant = await _png(spot: const ui.Rect.fromLTWH(0, 0, 5, 5));

    await expectLater(
      comparator.compare(variant, Uri.parse('golden.png')),
      throwsA(isA<FlutterError>()),
    );
  });
}
