import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '/l10n/app_localizations.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../../models/playling_from.dart';
import '../../services/downloader.dart';
import '../screens/Playlist/playlist_screen_controller.dart';
import '../widgets/snackbar.dart';
import '/services/synced_lyrics_service.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/navigator.dart';
import '/models/server.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/windows_audio_service.dart';
import '../../services/audio_handler.dart';
import '/services/discord_rpc_service.dart';
import '/services/playback_diagnostics_service.dart';
import '../../utils/helper.dart';
import '../../utils/server_storage.dart';
import '/models/media_Item_builder.dart';
import '../screens/Home/home_screen_controller.dart';
import '../screens/Library/library_controller.dart';
import '../widgets/sliding_up_panel.dart';
import '/models/durationstate.dart';
import '/services/music_service.dart';

part 'player_controller_playercontrollerbase.dart';
part 'player_controller_playerfav.dart';
part 'player_controller_playerlyrics.dart';
part 'player_controller_playermisc.dart';
part 'player_controller_playerplayback.dart';
part 'player_controller_playerqueue.dart';
part 'player_controller_playerradio.dart';
part 'player_controller_playersleep.dart';
part 'player_controller_playerstate.dart';
part 'player_controller_playervolume.dart';

class SyncedLyricLine {
  SyncedLyricLine({required this.timestamp, required this.text});
  final Duration timestamp;
  final String text;
}

class PlayerController extends GetxController
    with GetSingleTickerProviderStateMixin, _PlayerControllerBase, _PlayerFavMixin, _PlayerLyricsMixin, _PlayerMiscMixin, _PlayerPlaybackMixin, _PlayerQueueMixin, _PlayerRadioMixin, _PlayerSleepMixin, _PlayerStateMixin, _PlayerVolumeMixin
    implements PlayerStateProvider {
}


enum PlayButtonState { paused, playing, loading }
