import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wear_plus/wear_plus.dart';

import '../../services/wear_comm_service.dart';
import 'wear_home_screen.dart';

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
              home: const _WearRoot(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(bool isAmbient) {
    if (isAmbient) {
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

/// Root widget that switches between the no-connection screen and
/// the home screen with Navigator-based navigation.
class _WearRoot extends StatelessWidget {
  const _WearRoot();

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    return Obx(() {
      if (!comm.isReachable.value) {
        return const _NoConnectionScreen();
      }
      return const WearHomeScreen();
    });
  }
}

/// Shown when the watch can't reach the phone app.
class _NoConnectionScreen extends StatelessWidget {
  const _NoConnectionScreen();

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.phonelink_off, size: 32),
              const SizedBox(height: 10),
              Text(
                'No phone connected',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Make sure Doudou is running on your phone',
                textAlign: TextAlign.center,
                maxLines: 3,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => comm.retry(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Icon(
                    Icons.refresh,
                    size: 20,
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
