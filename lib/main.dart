import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/audio/just_audio_media_kit_ext.dart';
import 'services/audio/linux_locale_fix_stub.dart' if (dart.library.io) 'services/audio/linux_locale_fix.dart' as linux_locale;
import 'providers/app_state.dart';
import 'services/logging_service.dart';
import 'services/players/jellyfin_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/theme.dart';
import 'ui/layout/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runApp();
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JellyfinService.initializeVersion();

  try {
    await LoggingService().initialize();
  } catch (e) {
    // Logging initialization failed - continue without logging
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Desktop audio: just_audio_media_kit (mpv) for Windows/macOS and for Linux (YouTube only).
  // On Linux, set LC_NUMERIC=C before loading mpv to avoid "Non-C locale" crash.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      await linux_locale.ensureNumericLocaleC();
    }
    await JustAudioMediaKitExt.ensureInitializedAsync(
      linux: defaultTargetPlatform == TargetPlatform.linux,
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const DoudouApp());
  // Defer heavy system info logging until after first frame to avoid blocking initial paint.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _logSystemInfo('App');
  });
}

class DoudouApp extends StatelessWidget {
  const DoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: _buildAppWithPlatformServices(
        Consumer<AppState>(
            builder: (context, appState, child) {
              final systemBrightness =
                  WidgetsBinding.instance.platformDispatcher.platformBrightness;
              final brightness = appState.themeMode == ThemeMode.dark
                  ? Brightness.dark
                  : appState.themeMode == ThemeMode.light
                      ? Brightness.light
                      : systemBrightness;
              final oled = appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled;
              DesktopTheme.updateBrightness(brightness, oled: oled);
              DesktopTheme.updateAccent(appState.accentColor);

              return MaterialApp(
                title: 'Doudou - Jellyfin Music Player',
                theme: AppleTheme.light(accentColor: appState.accentColor),
                darkTheme: AppleTheme.dark(
                  accentColor: appState.accentColor,
                  oled: appState.oledDarkModeEnabled,
                ),
                themeMode: appState.themeMode,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                locale: appState.locale,
                home: Builder(
                  builder: (context) {
                    if (!appState.isInitialized) {
                      return const Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading...', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      );
                    }

                    return const AppShell();
                  },
                ),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
      ),
    );
  }

  /// Wraps the app with platform-specific services
  Widget _buildAppWithPlatformServices(Widget app) {
    return app;
  }
}

/// Log comprehensive system information for debugging, especially Flatpak issues
Future<void> _logSystemInfo(String context) async {
  if (!kDebugMode) return;

  final logger = LoggingService();

  try {
    logger.info('=== SYSTEM INFO START ($context) ===', 'SystemInfo');

    // Basic platform info (web-safe)
    if (!kIsWeb) {
      logger.info('Platform: ${Platform.operatingSystem}', 'SystemInfo');
      logger.info(
        'Platform version: ${Platform.operatingSystemVersion}',
        'SystemInfo',
      );
      logger.info(
        'Number of processors: ${Platform.numberOfProcessors}',
        'SystemInfo',
      );
    } else {
      logger.info('Platform: Web', 'SystemInfo');
    }
    logger.info('Flutter target: ${defaultTargetPlatform.name}', 'SystemInfo');
    logger.info('Is debug mode: $kDebugMode', 'SystemInfo');

    // Environment variables critical for Flatpak and media playback (not available on web)
    if (!kIsWeb) {
      final criticalEnvVars = [
        'FLATPAK_ID',
        'FLATPAK_DEST',
        'FLATPAK_SANDBOX_DIR',
        'LD_LIBRARY_PATH',
        'PATH',
        'HOME',
        'XDG_DATA_HOME',
        'XDG_CONFIG_HOME',
        'XDG_CACHE_HOME',
        'XDG_RUNTIME_DIR',
        'PULSE_RUNTIME_PATH',
        'PULSE_SYSTEM',
        'ALSA_PCM_CARD',
        'ALSA_PCM_DEVICE',
        'GST_PLUGIN_PATH',
        'GST_PLUGIN_SYSTEM_PATH',
        'GST_REGISTRY',
        'DISPLAY',
        'WAYLAND_DISPLAY',
        'PIPEWIRE_RUNTIME_DIR',
      ];

      logger.info('=== ENVIRONMENT VARIABLES ===', 'SystemInfo');
      for (final envVar in criticalEnvVars) {
        final value = Platform.environment[envVar];
        if (value != null) {
          logger.info('$envVar: $value', 'SystemInfo');
        } else {
          logger.info('$envVar: (not set)', 'SystemInfo');
        }
      }

      // Check if running in Flatpak
      final flatpakId = Platform.environment['FLATPAK_ID'];
      if (flatpakId != null) {
        logger.info('DETECTED: Running in Flatpak ($flatpakId)', 'SystemInfo');
      } else {
        logger.info('DETECTED: Not running in Flatpak', 'SystemInfo');
      }

      // Library path analysis
      final ldLibraryPath = Platform.environment['LD_LIBRARY_PATH'];
      if (ldLibraryPath != null) {
        logger.info('LD_LIBRARY_PATH directories:', 'SystemInfo');
        final paths = ldLibraryPath.split(':');
        for (int i = 0; i < paths.length; i++) {
          final dir = Directory(paths[i]);
          final exists = await dir.exists();
          logger.info('  [$i] ${paths[i]} (exists: $exists)', 'SystemInfo');
        }
      }
    } else {
      logger.info('=== WEB ENVIRONMENT ===', 'SystemInfo');
      logger.info(
        'Running in web browser - environment variables not available',
        'SystemInfo',
      );
    }

    // Check for media-related executables and libraries (not available on web)
    if (!kIsWeb) {
      final mediaCommands = [
        'gst-launch-1.0',
        'ffmpeg',
        'mpv',
        'pulseaudio',
        'pipewire',
      ];
      logger.info('=== MEDIA COMMAND AVAILABILITY ===', 'SystemInfo');
      for (final cmd in mediaCommands) {
        try {
          final result = await Process.run('which', [cmd]);
          if (result.exitCode == 0) {
            logger.info(
              '$cmd: ${result.stdout.toString().trim()}',
              'SystemInfo',
            );
          } else {
            logger.info('$cmd: not found', 'SystemInfo');
          }
        } catch (e) {
          logger.info('$cmd: error checking ($e)', 'SystemInfo');
        }
      }

      // Check GStreamer plugins
      try {
        final result = await Process.run('gst-inspect-1.0', [
          '--print-all',
        ]).timeout(const Duration(seconds: 5));
        if (result.exitCode == 0) {
          final plugins = result.stdout
              .toString()
              .split('\n')
              .where((line) => line.contains(':'))
              .take(10);
          logger.info(
            'GStreamer plugins (first 10): ${plugins.join(', ')}',
            'SystemInfo',
          );
        } else {
          logger.info(
            'GStreamer plugins: failed to list (exit code: ${result.exitCode})',
            'SystemInfo',
          );
        }
      } catch (e) {
        logger.info('GStreamer plugins: error checking ($e)', 'SystemInfo');
      }

      // Audio system detection
      logger.info('=== AUDIO SYSTEM ===', 'SystemInfo');
      try {
        // Check PulseAudio
        final pulseResult = await Process.run('pulseaudio', [
          '--check',
          '-v',
        ]).timeout(const Duration(seconds: 3));
        logger.info(
          'PulseAudio status: exit code ${pulseResult.exitCode}',
          'SystemInfo',
        );
      } catch (e) {
        logger.info('PulseAudio status: error ($e)', 'SystemInfo');
      }

      try {
        // Check PipeWire
        final pipewireResult = await Process.run('pipewire', [
          '--version',
        ]).timeout(const Duration(seconds: 3));
        if (pipewireResult.exitCode == 0) {
          logger.info(
            'PipeWire: ${pipewireResult.stdout.toString().trim()}',
            'SystemInfo',
          );
        } else {
          logger.info('PipeWire: not available', 'SystemInfo');
        }
      } catch (e) {
        logger.info('PipeWire: error checking ($e)', 'SystemInfo');
      }
    } else {
      logger.info('=== WEB MEDIA ===', 'SystemInfo');
      logger.info(
        'Web platform: Using HTML5 audio/video elements',
        'SystemInfo',
      );
    }

    logger.info('=== SYSTEM INFO END ===', 'SystemInfo');
  } catch (e) {
    logger.error('Failed to log system info: $e', 'SystemInfo');
  }
}
