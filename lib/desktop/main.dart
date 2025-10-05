import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../providers/app_state.dart';
import '../screens/login/login.dart';
import 'templates/desktop_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

class DesktopHomeLayout extends StatelessWidget {
  const DesktopHomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const DesktopLayout();
  }
}