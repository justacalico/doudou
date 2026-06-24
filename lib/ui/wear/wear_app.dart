import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../services/wear_comm_service.dart';
import 'wear_home_screen.dart';
import 'wear_now_playing_screen.dart';
import 'wear_settings_screen.dart';

/// Root widget for the Wear OS app. Uses WatchShape for round/square
/// adaptation and AmbientMode for always-on display support.
class WearApp extends StatelessWidget {
  const WearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return AmbientMode(
          builder: (context, mode, child) {
            final isAmbient = mode == WearMode.ambient;
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(isAmbient),
              home: const _WearNavigation(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(bool isAmbient) {
    if (isAmbient) {
      // Minimal theme for ambient mode - black bg, minimal colors
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white54,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white54, fontSize: 12),
          titleMedium: TextStyle(color: Colors.white, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white54),
      );
    }
    // Active mode - dark theme that works well on watches
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE8A598),
        onPrimary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70, fontSize: 13),
        titleMedium: TextStyle(color: Colors.white, fontSize: 14),
        titleSmall: TextStyle(color: Colors.white60, fontSize: 12),
        labelLarge: TextStyle(color: Colors.white, fontSize: 16),
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 28),
    );
  }
}

/// Swipeable page navigation between Home, Now Playing, and Settings.
/// Rotary input cycles through pages.
class _WearNavigation extends StatefulWidget {
  const _WearNavigation();

  @override
  State<_WearNavigation> createState() => _WearNavigationState();
}

class _WearNavigationState extends State<_WearNavigation> {
  final _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    rotaryEvents.listen((event) {
      if (!mounted) return;
      final next = event.direction == RotaryDirection.clockwise
          ? (_currentPage + 1).clamp(0, 2)
          : (_currentPage - 1).clamp(0, 2);
      if (next == _currentPage) return;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    return Obx(() {
      if (!comm.isReachable.value) {
        return const _NoConnectionScreen();
      }
      return Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (p) => _currentPage = p,
          children: const [
            WearHomeScreen(),
            WearNowPlayingScreen(),
            WearSettingsScreen(),
          ],
        ),
      );
    });
  }
}

/// Shown when the watch can't reach the phone app. Lets the user
/// retry the connection manually.
class _NoConnectionScreen extends StatelessWidget {
  const _NoConnectionScreen();

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phonelink_off, size: 36),
              const SizedBox(height: 12),
              Text(
                'No phone connected',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure Doudou is running on your phone',
                textAlign: TextAlign.center,
                maxLines: 3,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => comm.retry(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Icon(
                    Icons.refresh,
                    size: 24,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
