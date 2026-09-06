import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'app_l10n.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopSystemTray extends GetxService with TrayListener {
  late WindowListener listener;
  final Rxn<MediaItem> currentSong = Rxn<MediaItem>();

  @override
  void onInit() {
    trayManager.addListener(this);
    Future.delayed(const Duration(seconds: 2), () => initSystemTray());
    super.onInit();
  }

  Future<void> initSystemTray() async {
    String path = GetPlatform.isWindows
        ? 'assets/icons/icon.ico'
        : 'assets/icons/icon.png';

    await windowManager.ensureInitialized();
    final playerController = Get.find<PlayerController>();

    await trayManager.setIcon(path);

    // Listen to current song changes
    playerController.currentSong.listen((song) {
      currentSong.value = song;
      updateContextMenu();
    });

    // create context menu
    await updateContextMenu();

    await windowManager.setPreventClose(true);
    listener = CloseWindowListener();
    windowManager.addListener(listener);
  }

  Future<void> updateContextMenu() async {
    final playerController = Get.find<PlayerController>();
    final song = currentSong.value;
    final l10n = l10nFromPrefs();

    // create context menu
    final Menu menu = Menu(items: [
      MenuItem(
        label: l10n.showHide,
        onClick: (menuItem) async => await windowManager.isVisible()
            ? await windowManager.hide()
            : await windowManager.show(),
      ),
      MenuItem.separator(),
      if (song != null) ...[
        MenuItem(
          label: l10n.traySong(song.title),
          disabled: true,
        ),
        MenuItem(
          label: l10n.trayAlbum(song.album ?? l10n.unknown),
          disabled: true,
        ),
        MenuItem(
          label: l10n.trayArtist(song.artist ?? l10n.unknown),
          disabled: true,
        ),
        MenuItem.separator(),
      ],
      MenuItem(
        label: l10n.prev,
        onClick: (menuItem) {
          if (playerController.currentQueue.isNotEmpty) {
            playerController.prev();
          }
        },
      ),
      MenuItem(
        label: l10n.playPause,
        onClick: (menuItem) {
          if (playerController.currentQueue.isNotEmpty) {
            playerController.playPause();
          }
        },
      ),
      MenuItem(
        label: l10n.next,
        onClick: (menuItem) {
          if (playerController.currentQueue.isNotEmpty) {
            playerController.next();
          }
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: l10n.quit,
        onClick: (menuItem) async {
          await Get.find<AudioHandler>().customAction("saveSession");
          exit(0);
        },
      ),
    ]);

    // set context menu
    await trayManager.setContextMenu(menu);
  }

  @override
  void onClose() {
    trayManager.removeListener(this);
    windowManager.removeListener(listener);
    super.onClose();
  }

  @override
  void onTrayIconMouseDown() {
    if (GetPlatform.isWindows) {
      windowManager.show();
    } else {
      trayManager.popUpContextMenu();
    }

    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (GetPlatform.isWindows) {
      trayManager.popUpContextMenu();
    } else {
      windowManager.show();
    }

    super.onTrayIconRightMouseDown();
  }
}

class CloseWindowListener extends WindowListener {
  @override
  Future<void> onWindowClose() async {
    final settingsScrnController = Get.find<SettingsScreenController>();
    if (settingsScrnController.backgroundPlayEnabled.isTrue &&
        Get.find<PlayerController>().buttonState.value ==
            PlayButtonState.playing) {
      await windowManager.hide();
    } else {
      await Get.find<AudioHandler>().customAction("saveSession");
      exit(0);
    }
  }
}
