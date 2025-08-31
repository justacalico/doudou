import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/login/login.dart';
import 'screens/bottom_bar.dart';

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
      child: CupertinoApp(
        title: 'Doudou - Jellyfin Music Player',
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemPurple,
          scaffoldBackgroundColor: CupertinoColors.systemBackground,
        ),
        home: Consumer<AppState>(
          builder: (context, appState, child) {
            if (appState.isLoggedIn) {
              return const HomeScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
