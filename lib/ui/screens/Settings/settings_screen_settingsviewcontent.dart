part of 'settings_screen.dart';

mixin _SettingsViewContentMixin on __SettingsViewStateBase {
  List<Widget> _buildContent(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final isDesktop = GetPlatform.isDesktop;

    return [
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return _SettingsListTile(
          title: context.l10n.setDiscoverContent,
          subtitle: Obx(() => Text(_discoverContentLabel(
              context, settings.discoverContentType.value))),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const DiscoverContentSelectorDialog(),
          ),
        );
      }),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return _SettingsListTile(
          title: context.l10n.homeContentCount,
          subtitle: context.l10n.homeContentCountDes,
          trailing: _SettingsDropdown<int>(
            value: settings.noOfHomeScreenContent.value,
            items: const [3, 5, 7, 9, 11].map((e) => (e, '$e')).toList(),
            onChanged: settings.setContentNumber,
          ),
        );
      }),
      if (isDesktop)
        _SettingsListTile(
          title: context.l10n.sidebarMode,
          subtitle: context.l10n.sidebarModeDes,
          trailing: Obx(() => _SettingsDropdown<SidebarMode>(
                value: settings.sidebarMode.value,
                items: [
                  (SidebarMode.auto, context.l10n.sidebarModeAuto),
                  (SidebarMode.collapsed, context.l10n.sidebarModeCollapsed),
                  (SidebarMode.expanded, context.l10n.sidebarModeExpanded),
                ],
                onChanged: settings.setSidebarMode,
              )),
        ),
      _SettingsListTile(
        title: context.l10n.cacheHomeScreenData,
        subtitle: context.l10n.cacheHomeScreenDataDes,
        trailing: Obx(() => CustSwitch(
              value: settings.cacheHomeScreenData.value,
              onChanged: settings.toggleCacheHomeScreenData,
            )),
        onTap: () => settings.toggleCacheHomeScreenData(
          !settings.cacheHomeScreenData.value,
        ),
      ),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return _SettingsListTile(
          title: context.l10n.piped,
          subtitle: context.l10n.linkPipedDes,
          trailing: TextButton(
            onPressed: () {
              if (settings.isLinkedWithPiped.isFalse) {
                showDialog(context: context, builder: (_) => const LinkPiped())
                    .whenComplete(() => Get.delete<PipedLinkedController>());
              } else {
                settings.unlinkPiped();
              }
            },
            child: Text(settings.isLinkedWithPiped.value
                ? context.l10n.unLink
                : context.l10n.link),
          ),
        );
      }),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt || !settings.isLinkedWithPiped.value) {
          return const SizedBox.shrink();
        }
        return _SettingsListTile(
          title: context.l10n.resetblacklistedplaylist,
          subtitle: context.l10n.resetblacklistedplaylistDes,
          trailing: TextButton(
            onPressed: () async {
              await Get.find<LibraryPlaylistsController>()
                  .resetBlacklistedPlaylist();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                snackbar(context, context.l10n.blacklistPlstResetAlert,
                    size: SnackBarSize.MEDIUM),
              );
            },
            child: Text(context.l10n.reset),
          ),
        );
      }),
      _SettingsListTile(
        title: context.l10n.clearImgCache,
        subtitle: context.l10n.clearImgCacheDes,
        onTap: () async {
          await settings.clearImagesCache();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, context.l10n.clearImgCacheAlert,
                size: SnackBarSize.BIG),
          );
        },
      ),
    ];
  }

  String _discoverContentLabel(BuildContext context, String value) {
    final l10n = context.l10n;
    return switch (value) {
      'QP' => l10n.quickpicks,
      'TMV' => l10n.topmusicvideos,
      'TR' => l10n.trending,
      'BOLI' => l10n.basedOnLast,
      _ => value,
    };
  }

}
