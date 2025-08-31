import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/app_state.dart';
import 'screens/Login/login.dart';
import 'screens/controller/navbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
