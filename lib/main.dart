import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'providers/app_state.dart';
import 'screens/login/login.dart';
import 'screens/partials/navbar/navbar.dart';

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
  
  // Allow both orientations for Android Auto compatibility
  // Android Auto requires landscape orientation support
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  runApp(const DoudouApp());
}

class DoudouApp extends StatelessWidget {
  const DoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: _buildAppWithPlatformServices(
        CupertinoApp(
          title: 'Doudou - Jellyfin Music Player',
          theme: const CupertinoThemeData(
            primaryColor: CupertinoColors.systemPurple,
            scaffoldBackgroundColor: CupertinoColors.systemBackground,
          ),
          home: Consumer<AppState>(
            builder: (context, appState, child) {
              // Show loading screen while initializing
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
              
              if (appState.isLoggedIn) {
                return const HomeScreen();
              } else {
                return const LoginScreen();
              }
            },
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }

  /// Wraps the app with platform-specific services
  Widget _buildAppWithPlatformServices(Widget app) {
    // On Android and macOS, use AudioServiceWidget for background audio support
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)) {
      return AudioServiceWidget(child: app);
    }
    
    // On other platforms (including web), return the app directly
    return app;
  }
}
