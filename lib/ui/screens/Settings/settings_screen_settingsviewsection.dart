part of 'settings_screen.dart';

mixin _SettingsViewSectionMixin on __SettingsViewStateBase {
  List<Widget> _buildSectionChildren(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    _SettingsSectionId id,
  ) {
    return switch (id) {
      _SettingsSectionId.personalisation =>
        _buildPersonalisation(context, settings),
      _SettingsSectionId.content => _buildContent(context, settings),
      _SettingsSectionId.playback => _buildPlayback(context, settings),
      _SettingsSectionId.servers => _buildServers(context, settings, sync),
      _SettingsSectionId.download => _buildDownload(context, settings),
      _SettingsSectionId.backup => _buildBackup(context),
      _SettingsSectionId.misc => _buildMisc(context, settings),
      _SettingsSectionId.info => _buildInfo(context, settings),
    };
  }

}
