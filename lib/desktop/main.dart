import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../providers/app_state.dart';
import '../services/logging_service.dart';
import '../screens/login/login.dart';
import 'templates/desktop_layout.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging service
  try {
    await LoggingService().initialize();
    await _logSystemInfo('Desktop');
  } catch (e) {
    if (kDebugMode) {
      print('Failed to initialize logging service: $e');
    }
  }
  
  // Initialize sqflite for Linux/Windows/macOS
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.macOS)) {
    // Initialize the ffi database factory for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize MediaKit for Linux audio support
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    JustAudioMediaKit.ensureInitialized();
  }
  
  // Desktop-specific orientation settings (allow all orientations)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  runApp(const DesktopDoudouApp());
}

class DesktopDoudouApp extends StatelessWidget {
  const DesktopDoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: _buildAppWithPlatformServices(
        Consumer<AppState>(
          builder: (context, appState, child) {
            return MaterialApp(
              title: 'Doudou - Jellyfin Music Player',
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
              home: Consumer<AppState>(
                builder: (context, appState, child) {
                  // Show loading screen while initializing
                  if (!appState.isInitialized) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading Desktop App...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  if (appState.isLoggedIn) {
                    return const DesktopHomeLayout();
                  } else {
                    return const LoginScreen();
                  }
                },
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }

  /// Wraps the app with platform-specific services for desktop
  Widget _buildAppWithPlatformServices(Widget app) {
    // On macOS, use AudioServiceWidget for background audio support
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return AudioServiceWidget(child: app);
    }
    
    // On other desktop platforms and web, return the app directly
    return app;
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
    setState(() {
      // Trigger rebuild when navigation changes
    });
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

/// Log comprehensive system information for debugging, especially Flatpak issues
Future<void> _logSystemInfo(String context) async {
  final logger = LoggingService();
  
  try {
    logger.info('=== SYSTEM INFO START ($context) ===', 'SystemInfo');
    
    // Basic platform info
    logger.info('Platform: ${Platform.operatingSystem}', 'SystemInfo');
    logger.info('Platform version: ${Platform.operatingSystemVersion}', 'SystemInfo');
    logger.info('Number of processors: ${Platform.numberOfProcessors}', 'SystemInfo');
    logger.info('Flutter target: ${defaultTargetPlatform.name}', 'SystemInfo');
    logger.info('Is debug mode: $kDebugMode', 'SystemInfo');
    
    // Environment variables critical for Flatpak and media playback
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
    
    // Check for media-related executables and libraries
    final mediaCommands = ['gst-launch-1.0', 'ffmpeg', 'mpv', 'pulseaudio', 'pipewire'];
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
      final result = await Process.run('gst-inspect-1.0', ['--print-all']).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        final plugins = result.stdout.toString().split('\n').where((line) => line.contains(':')).take(10);
        logger.info('GStreamer plugins (first 10): ${plugins.join(', ')}', 'SystemInfo');
      } else {
        logger.info('GStreamer plugins: failed to list (exit code: ${result.exitCode})', 'SystemInfo');
      }
    } catch (e) {
      logger.info('GStreamer plugins: error checking ($e)', 'SystemInfo');
    }
    
    // Audio system detection
    logger.info('=== AUDIO SYSTEM ===', 'SystemInfo');
    try {
      // Check PulseAudio
      final pulseResult = await Process.run('pulseaudio', ['--check', '-v']).timeout(const Duration(seconds: 3));
      logger.info('PulseAudio status: exit code ${pulseResult.exitCode}', 'SystemInfo');
    } catch (e) {
      logger.info('PulseAudio status: error ($e)', 'SystemInfo');
    }
    
    try {
      // Check PipeWire
      final pipewireResult = await Process.run('pipewire', ['--version']).timeout(const Duration(seconds: 3));
      if (pipewireResult.exitCode == 0) {
        logger.info('PipeWire: ${pipewireResult.stdout.toString().trim()}', 'SystemInfo');
      } else {
        logger.info('PipeWire: not available', 'SystemInfo');
      }
    } catch (e) {
      logger.info('PipeWire: error checking ($e)', 'SystemInfo');
    }
    
    logger.info('=== SYSTEM INFO END ===', 'SystemInfo');
  } catch (e) {
    logger.error('Failed to log system info: $e', 'SystemInfo');
  }
}