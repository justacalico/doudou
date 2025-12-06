import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../screens/login/login.dart';
import 'pages/tv_home_screen.dart';

void main() {
  runApp(const DoudouApp());
}

class DoudouApp extends StatelessWidget {
  const DoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'Doudou',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.purple,
            brightness: Brightness.dark,
          ),
        ),
        // Use TV home screen if on Android TV flavor
        home: const AppInitializer(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isAndroidTV = false;

  @override
  void initState() {
    super.initState();
    _checkPlatform();
  }

  void _checkPlatform() {
    // Detect Android TV based on flavor or screen characteristics
    // This is a simplified check - in production, use proper flavor detection
    setState(() {
      _isAndroidTV = !kIsWeb && 
                     defaultTargetPlatform == TargetPlatform.android &&
                     MediaQuery.of(context).size.width > 1280;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Show TV interface if on Android TV
    if (_isAndroidTV && appState.isLoggedIn) {
      return const TVHomeScreen();
    }

    // Default mobile/desktop interface
    return const LoginScreen();
  }
}
