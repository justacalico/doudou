part of 'settings_screen_controller.dart';

mixin _SettingsDiagnosticsMixin on _SettingsScreenControllerBase {
  Future<void> clearPlaybackDiagnostics() async {
    await Get.find<PlaybackDiagnosticsService>().clear();
  }

  Future<String?> exportPlaybackDiagnostics() async {
    return Get.find<PlaybackDiagnosticsService>().exportToPickedLocation();
  }

  String getPlaybackDiagnosticsText({int limit = 400, bool pretty = false}) {
    final diag = Get.find<PlaybackDiagnosticsService>();
    if (pretty) {
      return diag.getEventsAsPrettyText(limit: limit);
    }
    return diag.getEventsAsJsonl(limit: limit);
  }

  Future<bool> copyPlaybackDiagnosticsToClipboard(
      {int limit = 400, bool pretty = false}) async {
    final text = getPlaybackDiagnosticsText(limit: limit, pretty: pretty);
    if (text.trim().isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

}
