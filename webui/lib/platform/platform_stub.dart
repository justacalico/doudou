import 'dart:typed_data';

import '../token_store.dart';

/// Fallbacks for non-web environments (tests run on the Dart VM where
/// package:web cannot compile).
TokenStore createTokenStore() => MemoryTokenStore();

Future<Uint8List?> pickHmbFile() async => null;

void triggerDownload(Uint8List bytes, String filename) {
  throw UnsupportedError('downloads only work in the browser');
}
