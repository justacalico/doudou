// Set locale to "C" before initializing media_kit/mpv on Linux to avoid
// "Non-C locale detected" crash. Primary fix is in linux/runner/main.cc;
// this is a fallback when running from Dart. Only used when enabling media_kit for YouTube on Linux.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

// From locale.h: LC_ALL = 0, LC_NUMERIC = 2
const int _lcAll = 0;

typedef _SetLocaleNative = Pointer<Int8> Function(Int32 category, Pointer<Int8> locale);
typedef _SetLocaleDart = Pointer<Int8> Function(int category, Pointer<Int8> locale);

typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);

typedef _FreeNative = Void Function(Pointer<Void> ptr);
typedef _FreeDart = void Function(Pointer<Void> ptr);

/// Call setlocale(LC_ALL, "C") on Linux so mpv does not crash.
/// No-op on other platforms. Call before JustAudioMediaKit.ensureInitialized(linux: true).
/// Primary fix is in the native Linux runner (main.cc); this is a fallback.
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
      final result = setlocale(_lcAll, cLocale.cast<Int8>());
      if (kDebugMode && result != Pointer.fromAddress(0)) {
        debugPrint('LinuxLocaleFix: setlocale(LC_ALL, "C") succeeded');
      } else if (kDebugMode && result == Pointer.fromAddress(0)) {
        debugPrint('LinuxLocaleFix: setlocale(LC_ALL, "C") returned null');
      }
    } finally {
      free(cLocale);
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('LinuxLocaleFix: setlocale failed: $e');
    }
    // App will continue; native runner may have already set locale
  }
}
