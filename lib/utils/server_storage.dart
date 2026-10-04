import 'package:get/get.dart';

import '/ui/screens/Settings/settings_screen_controller.dart';
import 'box_names.dart';

export 'box_names.dart';

int currentServerId() =>
    Get.find<SettingsScreenController>().activeServerId.value ?? 0;

String playlistSongsBoxName(String playlistId) {
  if (playlistId == 'LIBFAV') return libFavBoxName(currentServerId());
  if (playlistId == 'LIBRP') return recentlyPlayedBoxName(currentServerId());
  return playlistId;
}
