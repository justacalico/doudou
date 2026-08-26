part of 'settings_screen.dart';

mixin _SettingsViewMiscMixin on __SettingsViewStateBase {
  List<Widget> _buildMisc(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final isDesktop = GetPlatform.isDesktop;

    return [
      _SettingsListTile(
        title: context.l10n.playbackDiagnosticsRelease,
        subtitle: 'Record bounded playback/network events for troubleshooting.',
        trailing: Obx(() => CustSwitch(
              value: settings.playbackDiagnosticsEnabled.value,
              onChanged: settings.togglePlaybackDiagnostics,
            )),
        onTap: () => settings.togglePlaybackDiagnostics(
          !settings.playbackDiagnosticsEnabled.value,
        ),
      ),
      _SettingsListTile(
        title: context.l10n.viewPlaybackDiagnostics,
        subtitle: context.l10n.viewPlaybackDiagnosticsSubtitle,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlaybackDiagnosticsPage(),
          ),
        ),
      ),
      _SettingsListTile(
        title: context.l10n.clearPlaybackDiagnostics,
        subtitle: context.l10n.clearPlaybackDiagnosticsSubtitle,
        onTap: () async {
          final l10n = context.l10n;
          await settings.clearPlaybackDiagnostics();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.playbackDiagnosticsCleared)),
          );
        },
      ),
      if (isDesktop) ...[
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DoudouSpace.s16,
            DoudouSpace.s12,
            DoudouSpace.s16,
            DoudouSpace.s4,
          ),
          child: Text(
            'Discord Rich Presence',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.doudouColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        _SettingsListTile(
          leading: const Icon(Icons.discord, size: 20),
          title: 'Show Discord activity',
          subtitle: 'Display the current song as your Discord status.',
          trailing: Obx(() => CustSwitch(
                value: settings.discordRpcEnabled.value,
                onChanged: settings.toggleDiscordRpc,
              )),
          onTap: () => settings.toggleDiscordRpc(
            !settings.discordRpcEnabled.value,
          ),
        ),
        _SettingsListTile(
          leading: const Icon(Icons.vpn_key_outlined, size: 20),
          title: 'Discord Application ID',
          subtitle: Obx(() => Text(
                settings.discordAppId.value.isEmpty
                    ? 'Not set — create one at discord.com/developers/applications'
                    : settings.discordAppId.value,
                style: TextStyle(
                  color: settings.discordAppId.value.isEmpty
                      ? Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.7)
                      : null,
                ),
              )),
          onTap: () => _showDiscordAppIdDialog(context, settings),
        ),
        Obx(() => _SettingsListTile(
              leading: const Icon(Icons.bolt_outlined, size: 20),
              title: 'Test Discord connection',
              subtitle: Obx(() => Text(
                    settings.discordAppId.value.isEmpty
                        ? 'Set an Application ID first'
                        : 'Send a test activity to Discord',
                    style: TextStyle(
                      color: settings.discordAppId.value.isEmpty
                          ? context.doudouColors.textDisabled
                          : null,
                    ),
                  )),
              enabled: settings.discordAppId.value.isNotEmpty,
              onTap: settings.discordAppId.value.isNotEmpty
                  ? () => _testDiscordRpc(context, settings)
                  : null,
            )),
      ],
      _SettingsListTile(
        title: context.l10n.resetToDefault,
        subtitle: context.l10n.resetToDefaultDes,
        onTap: () async {
          await settings.resetAppSettingsToDefault();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, context.l10n.resetToDefaultMsg,
                size: SnackBarSize.BIG),
          );
        },
      ),
    ];
  }

  void _showDiscordAppIdDialog(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final controller = TextEditingController(text: settings.discordAppId.value);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Discord Application ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a Discord application at discord.com/developers/applications and paste the Application ID here.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: DoudouSpace.s12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Application ID',
                  hintText: 'e.g. 1234567890123456789',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                settings.setDiscordAppId(controller.text);
                Navigator.of(ctx).pop();
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  void _testDiscordRpc(
    BuildContext context,
    SettingsScreenController settings,
  ) async {
    if (!Get.isRegistered<DiscordRpcService>()) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(context, 'Discord RPC is not available on this platform',
            size: SnackBarSize.BIG),
      );
      return;
    }

    final svc = Get.find<DiscordRpcService>();
    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(context, 'Testing Discord connection...',
          size: SnackBarSize.BIG),
    );

    final success = await svc.testConnection();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(
        context,
        success
            ? 'Discord RPC is working! Check your Discord profile.'
            : 'Discord RPC test failed. Make sure Discord is running and the Application ID is correct.',
        size: SnackBarSize.BIG,
      ),
    );
  }

}
