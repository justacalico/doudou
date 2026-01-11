import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../services/logging_service.dart';
import '../../services/players/jellyfin_service.dart';
import '../mobile/login/login.dart';
import '../mobile/partials/navbar/navbar.dart';
import '../mobile/widgets/apple_design/apple_theme.dart';
import 'templates/desktop_layout.dart';
import 'services/navigation_service.dart';

const double kDesktopBreakpoint = 768.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runDesktopApp();
}

Future<void> runDesktopApp() async {
  try {
    await JellyfinService.initializeVersion();

    try {
      await LoggingService().initialize();
      await _logSystemInfo('Desktop');
    } catch (_) {}

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (_) {}
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      try {
        JustAudioMediaKit.ensureInitialized();
      } catch (_) {}
    }

    if (!kIsWeb) {
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {}
    }

    runApp(const DesktopDoudouApp());
  } catch (e) {
    runApp(
      MaterialApp(
        title: 'Doudou Test',
        home: Scaffold(
          backgroundColor: Colors.blue.shade100,
          appBar: AppBar(
            title: const Text('Doudou Test App'),
            backgroundColor: Colors.blue,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Test Window - Flutter is Working!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Original error: ${e.toString()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('This is a test - app is working'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopDoudouApp extends StatelessWidget {
  const DesktopDoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return ChangeNotifierProvider(
        create: (context) => AppState(),
        child: _buildAppWithPlatformServices(
          Consumer<AppState>(
            builder: (context, appState, child) {
              return MaterialApp(
                title: 'Doudou - Music Player',
                theme: AppleTheme.light(accentColor: appState.accentColor),
                darkTheme: AppleTheme.dark(accentColor: appState.accentColor),
                themeMode: appState.themeMode,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                locale: appState.locale,
                home: const _ResponsiveHome(),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        ),
      );
    } catch (e) {
      return MaterialApp(
        title: 'Doudou Error',
        home: Scaffold(body: Center(child: Text('Error: ${e.toString()}'))),
      );
    }
  }

  Widget _buildAppWithPlatformServices(Widget app) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return AudioServiceWidget(child: app);
    }
    return app;
  }
}

/// Responsive home widget that switches between mobile and desktop UI
class _ResponsiveHome extends StatelessWidget {
  const _ResponsiveHome();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
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

        if (!appState.isLoggedIn) {
          return const LoginScreen();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;

            if (isDesktop) {
              return const DesktopHomeLayout();
            } else {
              final baseTheme = Theme.of(context);
              return Theme(
                data: baseTheme.copyWith(
                  textTheme: baseTheme.textTheme.apply(
                    decoration: TextDecoration.none,
                  ),
                  primaryTextTheme: baseTheme.primaryTextTheme.apply(
                    decoration: TextDecoration.none,
                  ),
                ),
                child: const Material(
                  type: MaterialType.transparency,
                  child: HomeScreen(),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class DesktopHomeLayout extends StatefulWidget {
  const DesktopHomeLayout({super.key});

  @override
  State<DesktopHomeLayout> createState() => _DesktopHomeLayoutState();
}

class _DesktopHomeLayoutState extends State<DesktopHomeLayout> {
  final NavigationService _navigationService = NavigationService();

  @override
  void initState() {
    super.initState();
    // Listen to navigation changes from detail pages
    _navigationService.selectedPageIndex.addListener(_onNavigationChanged);
  }

  @override
  void dispose() {
    _navigationService.selectedPageIndex.removeListener(_onNavigationChanged);
    super.dispose();
  }

  void _onNavigationChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _navigationService.selectedPageIndex,
      builder: (context, selectedIndex, child) {
        return DesktopLayout(
          selectedIndex: selectedIndex,
          onNavigationChanged: () {
            setState(() {});
          },
        );
      },
    );
  }
}

Future<void> _logSystemInfo(String context) async {
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

    // Check for media-related executables and libraries (platform-specific, not available on web)
    if (!kIsWeb) {
      List<String> mediaCommands = [];
      if (defaultTargetPlatform == TargetPlatform.linux) {
        mediaCommands = [
          'gst-launch-1.0',
          'ffmpeg',
          'mpv',
          'pulseaudio',
          'pipewire',
        ];
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        mediaCommands = [
          'ffmpeg',
          'mpv',
        ]; // Only check commonly installed tools on macOS
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        mediaCommands = ['ffmpeg']; // Only check ffmpeg on Windows
      }

      logger.info('=== MEDIA COMMAND AVAILABILITY ===', 'SystemInfo');
      for (final cmd in mediaCommands) {
        try {
          final whichCmd = defaultTargetPlatform == TargetPlatform.windows
              ? 'where'
              : 'which';
          final result = await Process.run(whichCmd, [
            cmd,
          ]).timeout(const Duration(seconds: 2));
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
    } else {
      logger.info('=== WEB MEDIA ===', 'SystemInfo');
      logger.info(
        'Web platform: Using HTML5 audio/video elements',
        'SystemInfo',
      );
    }

    // Only check GStreamer on Linux (not available on web)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
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
    }

    // Audio system detection (platform-specific, not available on web)
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.linux) {
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
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        logger.info('=== AUDIO SYSTEM ===', 'SystemInfo');
        logger.info('macOS: Using Core Audio (native)', 'SystemInfo');
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        logger.info('=== AUDIO SYSTEM ===', 'SystemInfo');
        logger.info('Windows: Using DirectSound/WASAPI (native)', 'SystemInfo');
      }
    } else {
      logger.info('=== WEB AUDIO SYSTEM ===', 'SystemInfo');
      logger.info('Web: Using Web Audio API', 'SystemInfo');
    }

    logger.info('=== SYSTEM INFO END ===', 'SystemInfo');
  } catch (e) {
    logger.error('Failed to log system info: $e', 'SystemInfo');
  }
}
