import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_state.dart';
import 'services/logging_service.dart';
import 'services/responsive_service.dart';
import 'screens/login/login.dart';
import 'screens/partials/navbar/navbar.dart';
import 'desktop/templates/desktop_layout.dart';

void main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Run the unified responsive app
  await _runResponsiveApp();
}

/// Runs the unified app that adapts UI based on screen size, not platform.
/// 
/// This replaces the old platform-based detection with responsive design:
/// - Screen width >= 768px: Desktop layout (Material Design)
/// - Screen width < 768px: Mobile layout (Cupertino Design)
Future<void> _runResponsiveApp() async {
  // Initialize logging service
  try {
    await LoggingService().initialize();
    await _logSystemInfo('Responsive');
  } catch (e) {
    if (kDebugMode) {
      print('Failed to initialize logging service: $e');
    }
  }

  // Initialize sqflite for Linux/Windows/macOS
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize database: $e');
      }
    }
  }

  // Initialize MediaKit for Linux audio support
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    try {
      JustAudioMediaKit.ensureInitialized();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize MediaKit: $e');
      }
    }
  }

  // Allow all orientations for flexibility
  // This enables tablets to rotate and trigger layout changes
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const DoudouApp());
}

/// The main Doudou app widget that provides responsive UI based on screen size.
/// 
/// Uses LayoutBuilder to detect screen size changes and automatically switches
/// between mobile (Cupertino) and desktop (Material) layouts.
class DoudouApp extends StatelessWidget {
  const DoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return _buildAppWithPlatformServices(
            // Use a MaterialApp as the root since it supports both Material and Cupertino widgets
            // The actual UI style is determined by ResponsiveHomeScreen based on screen size
            MaterialApp(
              title: 'Doudou - Music Player',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: appState.accentColor,
                  brightness: Brightness.light,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: appState.accentColor,
                  brightness: Brightness.dark,
                ),
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
              home: const ResponsiveHomeScreen(),
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }

  /// Wraps the app with platform-specific services
  Widget _buildAppWithPlatformServices(Widget app) {
    // On Android and macOS, use AudioServiceWidget for background audio support
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AudioServiceWidget(child: app);
    }

    // On other platforms (including web), return the app directly
    return app;
  }
}

/// A responsive home screen that switches between mobile and desktop layouts
/// based on screen width, not device platform.
/// 
/// Breakpoints:
/// - < 768px: Mobile layout (optimized for phones and small screens)
/// - >= 768px: Desktop layout (full sidebar and expanded content)
class ResponsiveHomeScreen extends StatelessWidget {
  const ResponsiveHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine layout based on screen width
        final isDesktop = constraints.maxWidth >= ResponsiveService.desktopBreakpoint;
        
        return Consumer<AppState>(
          builder: (context, appState, child) {
            // Show loading screen while initializing
            if (!appState.isInitialized) {
              return _buildLoadingScreen(context, isDesktop);
            }

            // Show login screen if not logged in
            if (!appState.isLoggedIn) {
              return const LoginScreen();
            }

            // Show the appropriate main layout based on screen size
            if (isDesktop) {
              return const DesktopLayout();
            } else {
              return const MobileHomeScreen();
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      // Material design loading for desktop
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Cupertino-style loading for mobile (but using Material widgets since we're in MaterialApp)
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// Mobile home screen wrapper that uses the existing HomeScreen
class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // HomeScreen is the existing mobile navbar-based layout
    return const HomeScreen();
  }
}

/// Log comprehensive system information for debugging, especially Flatpak issues
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
      logger.info('Running in web browser - environment variables not available', 'SystemInfo');
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
            logger.info('$cmd: ${result.stdout.toString().trim()}', 'SystemInfo');
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
      logger.info('Web platform: Using HTML5 audio/video elements', 'SystemInfo');
    }

    logger.info('=== SYSTEM INFO END ===', 'SystemInfo');
  } catch (e) {
    logger.error('Failed to log system info: $e', 'SystemInfo');
  }
}
