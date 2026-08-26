import 'dart:async';
import '/l10n/app_localizations.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doudou/services/permission_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../utils/server_storage.dart';
import '../../../utils/update_check_flag_file.dart';
import '/services/piped_service.dart';
import '/services/library_sync_service.dart';
import '/services/playback_diagnostics_service.dart';
import '/services/discord_rpc_service.dart';
import '../Library/library_controller.dart';
import '../../widgets/snackbar.dart';
import '../../../utils/helper.dart';
import '/services/music_service.dart';
import '/ui/player/player_controller.dart';
import '../Home/home_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/app/settings/app_settings_controller.dart';

import '/models/server.dart';
import '/services/backend/backend_factory.dart';
import '/services/backend/jellyfin_backend.dart';
import '/services/backend/music_backend.dart';
import '/services/backend/subsonic_backend.dart';
import '/services/backend/noop_backend.dart';

part 'settings_screen_controller_settingsscreencontrollerbase.dart';
part 'settings_screen_controller_settingsdiagnostics.dart';
part 'settings_screen_controller_settingsdiscord.dart';
part 'settings_screen_controller_settingsother.dart';
part 'settings_screen_controller_settingsplayback.dart';
part 'settings_screen_controller_settingsserver.dart';
part 'settings_screen_controller_settingsstate.dart';
part 'settings_screen_controller_settingsstorage.dart';
part 'settings_screen_controller_settingsui.dart';

const bool kIsPlayStore =
    bool.fromEnvironment('PLAYSTORE', defaultValue: false);

enum SidebarMode { auto, collapsed, expanded }

enum NowPlayingLayout { sideView, playBar }

const supportedLocalesDisplay = {
  "en_AU": "English (Australian)",
  "zh": "简体中文",
  "ru": "Русский",
};

enum AnimationSpeed { off, fast, normal, slow }

enum SyncedLyricsHighlightStyle { block, karaoke }

class SettingsScreenController extends GetxController
    with _SettingsScreenControllerBase, _SettingsDiagnosticsMixin, _SettingsDiscordMixin, _SettingsOtherMixin, _SettingsPlaybackMixin, _SettingsServerMixin, _SettingsStateMixin, _SettingsStorageMixin, _SettingsUiMixin {
}

