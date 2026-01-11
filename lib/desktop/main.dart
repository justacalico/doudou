import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_state.dart';
import '../services/logging_service.dart';
import '../services/players/jellyfin_service.dart';
import '../screens/login/login.dart';
import '../mobile/screens/mobile_app_shell.dart'; // New Mobile UI
import '../widgets/apple_design/apple_theme.dart';
import 'templates/desktop_layout.dart';
import 'services/navigation_service.dart';

/// Breakpoint for switching between mobile and desktop UI
const double kDesktopBreakpoint = 768.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runDesktopApp();
}

/// Separated function to run desktop app without reinitializing bindings
Future<void> runDesktopApp() async {
  try {
    if (kDebugMode) {
      print('DEBUG: Starting runDesktopApp()');
    }

    // Initialize app version for Jellyfin service
    await JellyfinService.initializeVersion();

    // Initialize logging service
    try {
      if (kDebugMode) {
        print('DEBUG: About to initialize logging service');
      }
      await LoggingService().initialize();
      if (kDebugMode) {
        print('DEBUG: Logging service initialized, about to log system info');
      }
      await _logSystemInfo('Desktop');
      if (kDebugMode) {
        print('DEBUG: System info logged successfully');
      }
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
        if (kDebugMode) {
          print('DEBUG: About to initialize sqflite database');
        }
        // Initialize the ffi database factory for desktop platforms
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        if (kDebugMode) {
          print('DEBUG: Database initialized successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to initialize database: $e');
        }
      }
    }

    // Initialize MediaKit for Linux audio support
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      try {
        await _debugLinuxMpv();
        JustAudioMediaKit.ensureInitialized();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to initialize MediaKit: $e');
        }
      }
    }

    // Desktop-specific orientation settings (allow all orientations)
    if (!kIsWeb) {
      try {
        if (kDebugMode) {
          print('DEBUG: About to set orientation preferences');
        }
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        if (kDebugMode) {
          print('DEBUG: Orientation preferences set successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to set orientation preferences: $e');
        }
      }
    }

    if (kDebugMode) {
      print('About to start DesktopDoudouApp...');
    }

    // Start the app with error boundary
    runApp(const DesktopDoudouApp());

    if (kDebugMode) {
      print('DesktopDoudouApp started successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to start desktop app: $e');
      print('Stack trace: ${StackTrace.current}');
    }
    // Create a simple test app to verify Flutter works
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
                  onPressed: () {
                    // Try again
                    if (kDebugMode) {
                      print('Retry button pressed');
                    }
                  },
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
    if (kDebugMode) {
      print('DesktopDoudouApp.build() called');
    }

    try {
      if (kDebugMode) {
        print('Creating ChangeNotifierProvider...');
      }

      // Add error boundary and proper provider initialization
      return ChangeNotifierProvider(
        create: (context) {
          if (kDebugMode) {
            print('Creating AppState...');
          }
          return AppState();
        },
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
      if (kDebugMode) {
        print('Error in DesktopDoudouApp.build(): $e');
      }

      // Return a simple fallback widget
      return MaterialApp(
        title: 'Doudou Error',
        home: Scaffold(body: Center(child: Text('Error: ${e.toString()}'))),
      );
    }
  }

  /// Wraps the app with platform-specific services for desktop
  Widget _buildAppWithPlatformServices(Widget app) {
    // On macOS, use AudioServiceWidget for background audio support (not available on web)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return AudioServiceWidget(child: app);
    }

    // On other platforms (including web), return the app directly
    return app;
  }
}

/// Responsive home widget that switches between mobile and desktop UI
/// based on screen width
class _ResponsiveHome extends StatelessWidget {
  const _ResponsiveHome();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
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
                  Text('Loading...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }

        // Show login screen if not logged in
        if (!appState.isLoggedIn) {
          return const LoginScreen();
        }

        // Use LayoutBuilder to switch between mobile and desktop UI
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;

            if (isDesktop) {
              return const DesktopHomeLayout();
            } else {
              // Use mobile UI (MobileAppShell with bottom navigation)
              // Wrap with Theme to fix ALL text styling (removes yellow underlines)
              // that occur when Cupertino widgets are used in MaterialApp
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
                  child: MobileAppShell(),
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

/// Debug MPV availability and configuration on Linux for audio playback
Future<void> _debugLinuxMpv() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) return;

  if (kDebugMode) {
    print('');
    print('╔══════════════════════════════════════════════════════════════╗');
    print('║               LINUX MPV DEBUG OUTPUT                         ║');
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');
  }

  // Check if mpv binary exists
  if (kDebugMode) {
    print('🔍 Checking MPV installation...');
  }
  try {
    final whichResult = await Process.run('which', ['mpv']);
    if (whichResult.exitCode == 0) {
      final mpvPath = whichResult.stdout.toString().trim();
      if (kDebugMode) {
        print('  ✅ MPV found at: $mpvPath');
      }

      // Get MPV version
      final versionResult = await Process.run('mpv', ['--version']);
      if (versionResult.exitCode == 0) {
        final versionLines = versionResult.stdout.toString().split('\n');
        if (versionLines.isNotEmpty) {
          if (kDebugMode) {
            print('  ✅ MPV version: ${versionLines.first}');
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('  ❌ MPV NOT FOUND! Audio playback will likely fail.');
      }
      if (kDebugMode) {
        print('     Install with: sudo apt install mpv libmpv-dev');
      }
      if (kDebugMode) {
        print('     Or: sudo dnf install mpv mpv-libs-devel');
      }
      if (kDebugMode) {
        print('     Or: sudo pacman -S mpv');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('  ❌ Error checking MPV: $e');
    }
  }

  // Check for libmpv
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking libmpv library...');
  }
  try {
    final ldconfigResult = await Process.run('ldconfig', ['-p']);
    if (ldconfigResult.exitCode == 0) {
      final output = ldconfigResult.stdout.toString();
      final mpvLibs = output
          .split('\n')
          .where((line) => line.contains('libmpv'))
          .toList();
      if (mpvLibs.isNotEmpty) {
        if (kDebugMode) {
          print('  ✅ libmpv libraries found:');
        }
        for (final lib in mpvLibs) {
          if (kDebugMode) {
            print('     $lib');
          }
        }
      } else {
        if (kDebugMode) {
          print('  ❌ libmpv NOT FOUND in ldconfig cache!');
        }
        if (kDebugMode) {
          print('     Install with: sudo apt install libmpv-dev');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('  ⚠️  Could not check ldconfig: $e');
    }
  }

  // Check LD_LIBRARY_PATH
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking LD_LIBRARY_PATH...');
  }
  final ldPath = Platform.environment['LD_LIBRARY_PATH'];
  if (ldPath != null && ldPath.isNotEmpty) {
    if (kDebugMode) {
      print('  LD_LIBRARY_PATH: $ldPath');
    }
  } else {
    if (kDebugMode) {
      print('  LD_LIBRARY_PATH: (not set)');
    }
  }

  // Check for common MPV library paths
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking common library paths for libmpv...');
  }
  final commonPaths = [
    '/usr/lib/x86_64-linux-gnu/libmpv.so',
    '/usr/lib64/libmpv.so',
    '/usr/lib/libmpv.so',
    '/usr/local/lib/libmpv.so',
    '/app/lib/libmpv.so', // Flatpak
  ];
  for (final path in commonPaths) {
    final file = File(path);
    if (await file.exists()) {
      if (kDebugMode) {
        print('  ✅ Found: $path');
      }
    }
  }

  // Check if running in Flatpak
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking Flatpak environment...');
  }
  final flatpakId = Platform.environment['FLATPAK_ID'];
  if (flatpakId != null) {
    if (kDebugMode) {
      print('  ⚠️  Running in Flatpak: $flatpakId');
    }
    if (kDebugMode) {
      print('     MPV may need to be bundled or accessed via portal');
    }
  } else {
    if (kDebugMode) {
      print('  ✅ Not running in Flatpak');
    }
  }

  // Try to test MPV audio output
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking MPV audio outputs...');
  }
  try {
    final aoResult = await Process.run('mpv', ['--ao=help']);
    if (aoResult.exitCode == 0) {
      final output = aoResult.stdout.toString();
      final lines = output
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(10);
      if (kDebugMode) {
        print('  Available audio outputs:');
      }
      for (final line in lines) {
        if (kDebugMode) {
          print('     $line');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('  ❌ Could not query MPV audio outputs: $e');
    }
  }

  // Check PulseAudio/PipeWire status
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('🔍 Checking audio server...');
  }
  try {
    final paResult = await Process.run('pactl', ['info']);
    if (paResult.exitCode == 0) {
      final output = paResult.stdout.toString();
      final serverName = output
          .split('\n')
          .firstWhere((l) => l.contains('Server Name:'), orElse: () => '');
      if (serverName.isNotEmpty) {
        if (kDebugMode) {
          print('  ✅ $serverName');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('  ⚠️  Could not check PulseAudio/PipeWire: $e');
    }
  }

  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('╔══════════════════════════════════════════════════════════════╗');
  }
  if (kDebugMode) {
    print('║           END LINUX MPV DEBUG OUTPUT                         ║');
  }
  if (kDebugMode) {
    print('╚══════════════════════════════════════════════════════════════╝');
  }
  if (kDebugMode) {
    print('');
  }
}
