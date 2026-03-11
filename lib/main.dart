import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terminate_restart/terminate_restart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/l10n/app_localizations.dart';
import '/ui/screens/Search/search_screen_controller.dart';
import '/services/downloader.dart';
import '/services/library_sync_service.dart';
import '/services/piped_service.dart';
import '/services/playback_diagnostics_service.dart';
import 'utils/app_link_controller.dart';
import '/services/audio_handler.dart';
import '/services/music_service.dart';
import '/ui/navigator.dart';
import '/ui/player/player_controller.dart';
import 'ui/screens/Settings/settings_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/ui/design/doudou_motion.dart';
import 'ui/screens/Home/home_screen_controller.dart';
import 'ui/screens/Library/library_controller.dart';
import 'utils/system_tray.dart';
import 'utils/update_check_flag_file.dart';
import '/ui/widgets/playlist_album_scroll_behaviour.dart';
import '/utils/perf_monitor.dart';
import '/app/settings/app_settings_provider.dart';
import '/app/theme/app_theme_provider.dart';

final _perfMonitor = PerfMonitorController.devDefault();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  _setAppInitPrefs();
  startApplicationServices();
  Get.put<AudioHandler>(await initAudioService(), permanent: true);
  WidgetsBinding.instance.addObserver(LifecycleHandler());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  TerminateRestart.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!GetPlatform.isDesktop) Get.put(AppLinksController());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final settings = ref.watch(appSettingsProvider);
    final themeState = ref.watch(appThemeProvider);
    final locale = settings.locale;
    return GetMaterialApp(
        title: 'Doudou',
        scrollBehavior: PlaylistAlbumScrollBehaviour(),
        home: const ScreenNavigation(),
        debugShowCheckedModeBanner: false,
        locale: locale,
        fallbackLocale: const Locale("en", "AU"),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final mQuery = MediaQuery.of(context);
          final scale =
              mQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.1);
          return PerfMonitor(
            controller: _perfMonitor,
            child: Stack(
              children: [
                MediaQuery(
                  data: mQuery.copyWith(textScaler: scale),
                  child: AnimatedTheme(
                    duration: DoudouMotion.theme,
                    data: themeState.theme,
                    child: Stack(
                      children: [
                        child!,
                        const _AppLoadingOverlay(),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.transparent,
                      height: mQuery.padding.bottom,
                      width: mQuery.size.width,
                    ),
                  ),
                )
              ],
            ),
          );
        });
  }
}

Future<void> startApplicationServices() async {
  Get.lazyPut(() => PipedServices(), fenix: true);
  Get.lazyPut(() => MusicServices(), fenix: true);
  Get.lazyPut(() => ThemeController(), fenix: true);
  Get.lazyPut(() => PlayerController(), fenix: true);
  Get.lazyPut(() => HomeScreenController(), fenix: true);
  Get.lazyPut(() => LibrarySongsController(), fenix: true);
  Get.lazyPut(() => LibraryPlaylistsController(), fenix: true);
  Get.lazyPut(() => LibraryAlbumsController(), fenix: true);
  Get.lazyPut(() => LibraryArtistsController(), fenix: true);
  Get.lazyPut(() => SettingsScreenController(), fenix: true);
  Get.lazyPut(() => Downloader(), fenix: true);
  Get.lazyPut(() => LibrarySyncService(), fenix: true);
  Get.lazyPut(() => SearchScreenController(), fenix: true);
  Get.lazyPut(() => PlaybackDiagnosticsService(), fenix: true);
  if (GetPlatform.isDesktop) {
    Get.put(DesktopSystemTray());
  }
}

initHive() async {
  String applicationDataDirectoryPath;
  if (GetPlatform.isDesktop) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/db";
  } else {
    applicationDataDirectoryPath =
        (await getApplicationDocumentsDirectory()).path;
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox("SongsCache");
  await Hive.openBox("SongDownloads");
  await Hive.openBox("LIBFAV");
  await Hive.openBox('SongsUrlCache');
  await Hive.openBox("AppPrefs");
  await Hive.openBox(PlaybackDiagnosticsService.boxName);
}

void _setAppInitPrefs() {
  final appPrefs = Hive.box("AppPrefs");
  if (appPrefs.isEmpty) {
    appPrefs.putAll({
      'themeModeType': 1,
      "cacheSongs": false,
      "skipSilenceEnabled": false,
      'streamingQuality': 1,
      'themePrimaryColor': 4278199603,
      'dynamicColorPrimary': 4278199603,
      'discoverContentType': "QP",
      'newVersionVisibility': updateCheckFlag,
      "cacheHomeScreenData": true,
      PlaybackDiagnosticsService.enabledKey: false,
    });
  } else if (!appPrefs.containsKey(PlaybackDiagnosticsService.enabledKey)) {
    appPrefs.put(PlaybackDiagnosticsService.enabledKey, false);
  }
}

class _AppLoadingOverlay extends StatefulWidget {
  const _AppLoadingOverlay();

  @override
  State<_AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<_AppLoadingOverlay> {
  var _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class LifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (Get.isRegistered<LibrarySyncService>()) {
        Get.find<LibrarySyncService>().onAppResumed();
      }
    } else if (state == AppLifecycleState.detached) {
      await Get.find<AudioHandler>().customAction("saveSession");
    }
  }
}
