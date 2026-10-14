import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../token_store.dart';

class LocalTokenStore implements TokenStore {
  static const _key = 'doudou.webui.token';

  @override
  String? read() => web.window.localStorage.getItem(_key);

  @override
  void write(String token) => web.window.localStorage.setItem(_key, token);

  @override
  void clear() => web.window.localStorage.removeItem(_key);
}

TokenStore createTokenStore() => LocalTokenStore();

/// Opens the browser file picker and resolves with the selected file's
/// bytes, or null when the dialog is dismissed.
Future<Uint8List?> pickHmbFile() {
  final completer = Completer<Uint8List?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = '.hmb';
  input.oncancel = (web.Event _) {
    if (!completer.isCompleted) completer.complete(null);
  }.toJS;
  input.onchange = (web.Event _) {
    unawaited(_read(input, completer));
  }.toJS;
  input.click();
  return completer.future;
}

Future<void> _read(
    web.HTMLInputElement input, Completer<Uint8List?> completer) async {
  final file = input.files?.item(0);
  if (file == null) {
    if (!completer.isCompleted) completer.complete(null);
    return;
  }
  try {
    final buffer = await file.arrayBuffer().toDart;
    if (!completer.isCompleted) {
      completer.complete(buffer.toDart.asUint8List());
    }
  } catch (e) {
    if (!completer.isCompleted) completer.completeError(e);
  }
}

/// Hands [bytes] to the browser as a file download.
void triggerDownload(Uint8List bytes, String filename) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
