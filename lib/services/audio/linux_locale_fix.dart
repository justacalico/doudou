// Set LC_NUMERIC to "C" before initializing media_kit/mpv on Linux to avoid
// "Non-C locale detected" crash. Only used when enabling media_kit for YouTube on Linux.

import 'dart:ffi';
import 'dart:io';

// LC_NUMERIC from locale.h
const int _lcNumeric = 2;

typedef _SetLocaleNative = Pointer<Int8> Function(Int32 category, Pointer<Int8> locale);
typedef _SetLocaleDart = Pointer<Int8> Function(int category, Pointer<Int8> locale);

typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);

typedef _FreeNative = Void Function(Pointer<Void> ptr);
typedef _FreeDart = void Function(Pointer<Void> ptr);

/// Call setlocale(LC_NUMERIC, "C") on Linux so mpv does not crash.
/// No-op on other platforms. Call before JustAudioMediaKit.ensureInitialized(linux: true).
Future<void> ensureNumericLocaleC() async {
  if (!Platform.isLinux) return;
  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final setlocalePtr = libc.lookup<NativeFunction<_SetLocaleNative>>('setlocale');
    final setlocale = setlocalePtr.asFunction<_SetLocaleDart>();
    final mallocPtr = libc.lookup<NativeFunction<_MallocNative>>('malloc');
    final malloc = mallocPtr.asFunction<_MallocDart>();
    final freePtr = libc.lookup<NativeFunction<_FreeNative>>('free');
    final free = freePtr.asFunction<_FreeDart>();

    // Allocate "C\0"
    final cLocale = malloc(2);
    if (cLocale == Pointer.fromAddress(0)) return;
    try {
      final p = cLocale.cast<Uint8>();
      p[0] = 67; // 'C'
      p[1] = 0;
      setlocale(_lcNumeric, cLocale.cast<Int8>());
    } finally {
      free(cLocale);
    }
  } catch (_) {
    // Ignore; app will continue without locale fix (may crash when playing YT on Linux)
  }
}
