part of 'settings_screen_controller.dart';

mixin _SettingsDiscordMixin on _SettingsScreenControllerBase {
  void toggleDiscordRpc(bool val) {
    setBox.put('discordRpcEnabled', val);
    discordRpcEnabled.value = val;
    if (Get.isRegistered<DiscordRpcService>()) {
      Get.find<DiscordRpcService>().reconfigure();
    }
  }

  void setDiscordAppId(String val) {
    final trimmed = val.trim();
    setBox.put('discordAppId', trimmed);
    discordAppId.value = trimmed;
  }

}
