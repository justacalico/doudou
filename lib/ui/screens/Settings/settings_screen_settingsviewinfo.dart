part of 'settings_screen.dart';

mixin _SettingsViewInfoMixin on __SettingsViewStateBase {
  List<Widget> _buildInfo(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    return [
      _SettingsListTile(
        leading: const Icon(Icons.system_update_alt, size: 20),
        title: context.l10n.checkForUpdatesOnStartup,
        trailing: Obx(() => CustSwitch(
              value: settings.checkForUpdatesOnStartup.value,
              onChanged: settings.toggleCheckForUpdatesOnStartup,
            )),
        onTap: () => settings.toggleCheckForUpdatesOnStartup(
          !settings.checkForUpdatesOnStartup.value,
        ),
      ),
      _SettingsListTile(
        leading: const Icon(Icons.system_update, size: 20),
        title: context.l10n.checkForUpdates,
        onTap: () async {
          final checking = context.l10n.checkingForUpdates;
          final upToDate = context.l10n.upToDate;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(checking)));
          final info = await PackageInfo.fromPlatform();
          final latest = await newVersionCheck(info.version);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (latest != null) {
            settings.latestAvailableVersion.value = latest;
            settings.isNewVersionAvailable.value = true;
            showDialog(
              context: context,
              builder: (_) => NewVersionDialog(latestVersion: latest),
            );
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(upToDate)));
          }
        },
      ),
      _SettingsListTile(
        leading: const Icon(Icons.public, size: 20),
        title: context.l10n.openGitlab,
        subtitle: context.l10n.gitlabDes,
        onTap: () => launchUrl(
          Uri.parse('https://gitlab.com/Openlyst/doudou/'),
          mode: LaunchMode.externalApplication,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: DoudouSpace.s20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onLongPress: () {
                if (kIsPlayStore && !ytmProviderUnlocked) {
                  ytmProviderUnlocked = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Additional providers unlocked'),
                    ),
                  );
                }
              },
              child: Image.asset(
                'assets/icons/icon.png',
                width: 48,
                height: 48,
              ),
            ),
            const SizedBox(width: DoudouSpace.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doudou',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(settings.currentVersion),
              ],
            ),
          ],
        ),
      ),
    ];
  }

}
