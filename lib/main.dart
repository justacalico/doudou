import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'l10n/app_localizations.dart';
import 'providers/app_state.dart';
import 'services/audio/just_audio_media_kit_ext.dart';
import 'services/logging_service.dart';
import 'services/players/jellyfin_service.dart';
import 'services/voice_command_handler.dart';
import 'ui/rewrite/login/adaptive_login.dart';
import 'ui/rewrite/shell/adaptive_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeRuntime();
  runApp(const DoudouApp());
}

Future<void> _initializeRuntime() async {
  await JellyfinService.initializeVersion();

  try {
    await LoggingService().initialize();
    await _logSystemInfo();
  } catch (_) {}

  if (!kIsWeb && _isDesktopPlatform) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (_) {}

    try {
      JustAudioMediaKitExt.ensureInitialized();
    } catch (_) {}
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

bool get _isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

bool get _isCupertinoPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class DoudouApp extends StatelessWidget {
  const DoudouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: _buildWithPlatformServices(
        VoiceCommandHandler(
          child: Consumer<AppState>(
            builder: (context, appState, _) {
              final app = _isCupertinoPlatform
                  ? _buildCupertinoApp(appState)
                  : _buildMaterialApp(appState);
              return app;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialApp(AppState appState) {
    return MaterialApp(
      title: 'Doudou',
      debugShowCheckedModeBanner: false,
      locale: appState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: appState.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: appState.accentColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: appState.accentColor,
        brightness: Brightness.dark,
      ),
      home: const _RootGate(),
    );
  }

  Widget _buildCupertinoApp(AppState appState) {
    final brightness = _effectiveBrightness(appState.themeMode);

    return CupertinoApp(
      title: 'Doudou',
      debugShowCheckedModeBanner: false,
      locale: appState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: appState.accentColor,
      ),
      home: const _RootGate(),
    );
  }

  Widget _buildWithPlatformServices(Widget child) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AudioServiceWidget(child: child);
    }
    return child;
  }

  Brightness _effectiveBrightness(ThemeMode mode) {
    if (mode == ThemeMode.light) {
      return Brightness.light;
    }

    if (mode == ThemeMode.dark) {
      return Brightness.dark;
    }

    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.isInitialized) {
          return _LoadingView(isCupertino: _isCupertinoPlatform);
        }

        if (!appState.isLoggedIn) {
          return const AdaptiveLoginView();
        }

        return const AdaptiveShell();
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.isCupertino});

  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context).loading;

    final child = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isCupertino
              ? const CupertinoActivityIndicator(radius: 16)
              : const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(text),
        ],
      ),
    );

    if (isCupertino) {
      return CupertinoPageScaffold(child: child);
    }

    return Scaffold(body: child);
  }
}

Future<void> _logSystemInfo() async {
  final logger = LoggingService();

  try {
    logger.info('=== SYSTEM INFO START ===', 'SystemInfo');

    if (!kIsWeb) {
      logger.info('Platform: ${Platform.operatingSystem}', 'SystemInfo');
      logger.info(
        'Platform version: ${Platform.operatingSystemVersion}',
        'SystemInfo',
      );
    } else {
      logger.info('Platform: Web', 'SystemInfo');
    }

    logger.info('Flutter target: ${defaultTargetPlatform.name}', 'SystemInfo');
    logger.info('=== SYSTEM INFO END ===', 'SystemInfo');
  } catch (e) {
    logger.error('Failed to log system info: $e', 'SystemInfo');
  }
}
