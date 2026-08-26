part of 'settings_screen.dart';

mixin _SettingsViewDownloadMixin on __SettingsViewStateBase {
  List<Widget> _buildDownload(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    return [
      _SettingsListTile(
        title: context.l10n.autoDownFavSong,
        subtitle: context.l10n.autoDownFavSongDes,
        trailing: Obx(() => CustSwitch(
              value: settings.autoDownloadFavoriteSongEnabled.value,
              onChanged: settings.toggleAutoDownloadFavoriteSong,
            )),
        onTap: () => settings.toggleAutoDownloadFavoriteSong(
          !settings.autoDownloadFavoriteSongEnabled.value,
        ),
      ),
      _SettingsListTile(
        title: context.l10n.downloadingFormat,
        subtitle: context.l10n.downloadingFormatDes,
        trailing: Obx(() => _SettingsDropdown<String>(
              value: settings.downloadingFormat.value,
              items: const [
                ('opus', 'Opus/Ogg'),
                ('m4a', 'M4a'),
              ],
              onChanged: settings.changeDownloadingFormat,
            )),
      ),
      _SettingsListTile(
        title: context.l10n.downloadLocation,
        subtitle: Obx(() => Text(
              settings.isCurrentPathsupportDownDir
                  ? 'In App storage directory'
                  : settings.downloadLocationPath.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
        trailing: TextButton(
          onPressed: settings.resetDownloadLocation,
          child: Text(context.l10n.reset),
        ),
        onTap: settings.setDownloadLocation,
      ),
      if (GetPlatform.isAndroid)
        _SettingsListTile(
          title: context.l10n.exportDowloadedFiles,
          subtitle: context.l10n.exportDowloadedFilesDes,
          onTap: () => showDialog(
            context: context,
            builder: (_) => const ExportFileDialog(),
          ).whenComplete(() => Get.delete<ExportFileDialogController>()),
        ),
      if (GetPlatform.isAndroid)
        _SettingsListTile(
          title: context.l10n.exportedFileLocation,
          subtitle: Obx(() => Text(
                settings.exportLocationPath.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
          onTap: settings.setExportedLocation,
        ),
    ];
  }

  List<Widget> _buildBackup(BuildContext context) {
    return [
      _SettingsListTile(
        title: context.l10n.backupAppData,
        subtitle: context.l10n.backupSettingsAndPlaylistsDes,
        onTap: () => showDialog(
          context: context,
          builder: (_) => const BackupDialog(),
        ).whenComplete(() => Get.delete<BackupDialogController>()),
      ),
      _SettingsListTile(
        title: context.l10n.restoreAppData,
        subtitle: context.l10n.restoreSettingsAndPlaylistsDes,
        onTap: () => showDialog(
          context: context,
          builder: (_) => const RestoreDialog(),
        ).whenComplete(() => Get.delete<RestoreDialogController>()),
      ),
    ];
  }

}
