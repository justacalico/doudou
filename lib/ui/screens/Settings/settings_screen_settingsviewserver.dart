part of 'settings_screen.dart';

mixin _SettingsViewServerMixin on __SettingsViewStateBase {
  List<Widget> _buildServers(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
  ) {
    final colors = context.doudouColors;

    return [
      _SettingsListTile(
        title: context.l10n.addServer,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.add, color: colors.textSecondary),
        ),
        onTap: () => _showAddProviderPicker(context),
      ),
      const SizedBox(height: DoudouSpace.s8),
      Obx(() {
        final servers = settings.servers;
        final activeId = settings.activeServerId.value;

        if (servers.isEmpty) {
          return _SettingsListTile(
            title: context.l10n.noServersConfigured,
            enabled: false,
          );
        }

        return RadioGroup<int>(
          groupValue: activeId,
          onChanged: (v) {
            if (v != null) settings.setActiveServer(v);
          },
          child: Column(
            children: servers.map((server) {
              return _SettingsListTile(
                leading:
                    Icon(serverIcon(server.type), color: colors.textSecondary),
                title: server.name,
                subtitle: server.serverUrl?.isNotEmpty == true
                    ? server.serverUrl!
                    : serverTypeLabel(context, server.type),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<int>(value: server.id),
                    if (!server.isDefault) ...[
                      if (server.type != ServerType.youtubeMusic)
                        IconButton(
                          icon: const Icon(Icons.wifi_find, size: 18),
                          tooltip: context.l10n.testConnection,
                          onPressed: () async {
                            final err =
                                await settings.testServerConnection(server);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err == null
                                    ? context.l10n.connectionSuccess
                                    : '${context.l10n.connectionFailed}: $err'),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AddServerDialog(
                            serverType: server.type,
                            existing: server,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(context.l10n.deleteServer),
                              content: Text(context.l10n.deleteServerConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(context.l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: Text(context.l10n.delete),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            settings.removeServer(server.id);
                          }
                        },
                      ),
                    ],
                  ],
                ),
                onTap: () => settings.setActiveServer(server.id),
              );
            }).toList(),
          ),
        );
      }),
      Obx(() {
        final active = settings.activeServer;
        final isNonYouTube =
            active != null && active.type != ServerType.youtubeMusic;
        if (!isNonYouTube) return const SizedBox.shrink();
        return _SettingsListTile(
          title: context.l10n.resyncLibraryNow,
          trailing: TextButton(
            onPressed:
                sync.isSyncing.value ? null : () => settings.resyncLibraryNow(),
            child: Text(sync.isSyncing.value
                ? context.l10n.syncing
                : context.l10n.sync),
          ),
        );
      }),
    ];
  }

  Future<void> _showAddProviderPicker(BuildContext context) async {
    final selected = await showDialog<ServerType>(
      context: context,
      builder: (_) => const AddProviderDialog(),
    );
    if (selected == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AddServerDialog(serverType: selected),
    );
  }
}
