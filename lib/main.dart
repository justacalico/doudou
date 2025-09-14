import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/app_state.dart';
import 'screens/login/login.dart';
import 'screens/partials/navbar/navbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Allow both orientations for Android Auto compatibility
  // Android Auto requires landscape orientation support
  if (Platform.isAndroid) {
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
      child: AudioServiceWidget(
        child: CupertinoApp(
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
}
