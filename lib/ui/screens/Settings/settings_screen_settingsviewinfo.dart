part of 'settings_screen.dart';

mixin _SettingsViewInfoMixin on __SettingsViewStateBase {
  @override
  List<Widget> _buildInfo(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    return [
      _AppInfoHeader(
        version: settings.currentVersion,
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
      ),
      const Divider(height: 1),
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
        subtitle: _buildGitlabSubtitle(context),
        onTap: () => launchUrl(
          Uri.parse('https://gitlab.com/Openlyst/doudou/'),
          mode: LaunchMode.externalApplication,
        ),
      ),
    ];
  }

  Widget _buildGitlabSubtitle(BuildContext context) {
    final colors = context.doudouColors;
    final theme = Theme.of(context);
    final text = context.l10n.gitlabDes;
    final parts = text.split('⭐');
    final spans = <InlineSpan>[];

    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.star_rounded,
            size: 14,
            color: colors.accentPrimary,
          ),
        ));
      }
      spans.add(TextSpan(text: parts[i]));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colors.textTertiary,
      ),
    );
  }
}

class _AppInfoHeader extends StatelessWidget {
  const _AppInfoHeader({
    required this.version,
    this.onLongPress,
  });

  final String version;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.doudouColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DoudouSpace.s20,
        DoudouSpace.s24,
        DoudouSpace.s20,
        DoudouSpace.s20,
      ),
      child: Column(
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: ClipRRect(
              borderRadius: DoudouRadii.r16,
              child: Image.asset(
                'assets/icons/icon.png',
                width: 72,
                height: 72,
              ),
            ),
          ),
          const SizedBox(height: DoudouSpace.s12),
          Text(
            'Doudou',
            style: DoudouType.pageTitle,
          ),
          const SizedBox(height: DoudouSpace.s2),
          Text(
            version,
            style: DoudouType.body.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
