part of 'settings_screen.dart';

mixin _SettingsViewNavMixin on __SettingsViewStateBase {
  IconData _sectionIcon(_SettingsSectionId id) {
    return __SettingsViewStateBase._sectionMeta.firstWhere((e) => e.$1 == id).$2;
  }

  String _sectionTitle(BuildContext context, _SettingsSectionId id) {
    final l10n = context.l10n;
    final key = __SettingsViewStateBase._sectionMeta.firstWhere((e) => e.$1 == id).$3;
    return switch (key) {
      'personalisation' => l10n.personalisation,
      'content' => l10n.content,
      'musicPlayback' => l10n.musicPlayback,
      'servers' => l10n.servers,
      'download' => l10n.download,
      'backup' => l10n.backup,
      'misc' => l10n.misc,
      'appInfo' => l10n.appInfo,
      _ => key,
    };
  }

  String _sectionSubtitle(BuildContext context, _SettingsSectionId id) {
    final l10n = context.l10n;
    return switch (id) {
      _SettingsSectionId.servers => l10n.servers,
      _SettingsSectionId.backup => l10n.backupSettingsAndPlaylistsDes,
      _SettingsSectionId.content => l10n.content,
      _SettingsSectionId.playback => l10n.musicPlayback,
      _SettingsSectionId.misc => l10n.misc,
      _SettingsSectionId.personalisation => l10n.themeMode,
      _SettingsSectionId.download => l10n.download,
      _SettingsSectionId.info => l10n.appInfo,
    };
  }

  bool _isTv(BuildContext context) {
    if (!Get.isRegistered<TvService>()) return false;
    return Get.find<TvService>().isTV.value;
  }

}
