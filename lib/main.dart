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
/// - Screen width >= 768px: Complete Desktop UI (MaterialApp + Material Design)
/// - Screen width < 768px: Complete Mobile UI (CupertinoApp + Cupertino Design)
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

  runApp(const DoudouResponsiveApp());
}

/// The root widget that switches between complete Mobile and Desktop apps
/// based on screen size.
/// 
/// This widget uses a WidgetsApp with a builder to detect screen size BEFORE
/// creating the actual app, allowing us to switch between completely different
/// app shells (CupertinoApp vs MaterialApp).
class DoudouResponsiveApp extends StatelessWidget {
  const DoudouResponsiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We need to wrap everything in a widget that can detect screen size
    // and then build the appropriate app (Cupertino or Material)
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const _ResponsiveAppSwitcher(),
    );
  }
}

/// Switches between complete CupertinoApp (mobile) and MaterialApp (desktop)
/// based on screen width.
class _ResponsiveAppSwitcher extends StatelessWidget {
  const _ResponsiveAppSwitcher();

  @override
  Widget build(BuildContext context) {
    // Use WidgetsApp as a minimal shell to get MediaQuery access
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: Colors.purple,
      builder: (context, child) {
        // Now we have access to MediaQuery to check screen size
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= ResponsiveService.desktopBreakpoint;
        
        if (isDesktop) {
          return const _DesktopApp();
        } else {
          return const _MobileApp();
        }
      },
    );
  }
}

/// Complete Desktop App using MaterialApp with Material Design
class _DesktopApp extends StatelessWidget {
  const _DesktopApp();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return _buildAppWithPlatformServices(
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
            home: _buildDesktopHome(appState),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }

  Widget _buildDesktopHome(AppState appState) {
    if (!appState.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (!appState.isLoggedIn) {
      return const LoginScreen();
    }

    return const DesktopLayout();
  }

  Widget _buildAppWithPlatformServices(Widget app) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return AudioServiceWidget(child: app);
    }
    return app;
  }
}

/// Complete Mobile App using CupertinoApp with Cupertino Design
class _MobileApp extends StatelessWidget {
  const _MobileApp();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return _buildAppWithPlatformServices(
          CupertinoApp(
            title: 'Doudou - Jellyfin Music Player',
            theme: const CupertinoThemeData(
              primaryColor: CupertinoColors.systemPurple,
              scaffoldBackgroundColor: CupertinoColors.systemBackground,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: appState.locale,
            home: _buildMobileHome(appState),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }

  Widget _buildMobileHome(AppState appState) {
    if (!appState.isInitialized) {
      return const CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 20),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!appState.isLoggedIn) {
      return const LoginScreen();
    }

    // HomeScreen is the complete mobile UI with bottom navigation
    return const HomeScreen();
  }

  Widget _buildAppWithPlatformServices(Widget app) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AudioServiceWidget(child: app);
    }
    return app;
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
