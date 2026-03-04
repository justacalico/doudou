import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doudou/utils/helper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/common_dialog_widget.dart';
import '../../widgets/cust_switch.dart';
import '../../widgets/export_file_dialog.dart';
import '../../widgets/backup_dialog.dart';
import '../../widgets/restore_dialog.dart';
import '../Library/library_controller.dart';
import '../../widgets/snackbar.dart';
import '../../widgets/new_version_dialog.dart';
import '/ui/widgets/link_piped.dart';
import '/services/music_service.dart';
import '/services/library_sync_service.dart';
import '/ui/player/player_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/ui/constants/layout.dart';
import 'components/custom_expansion_tile.dart';
import 'sections/settings_personalisation_section.dart';
import '/models/server.dart';
import 'settings_screen_controller.dart';

class SettingsScreen extends GetView<SettingsScreenController> {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final settingsController = controller;
    final syncService = Get.find<LibrarySyncService>();
    final sectionKeys = settingsController.settingsSectionKeys;
    void handleSectionExpansion(int index, bool expanded) {
      if (!expanded) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        for (var i = 0; i < sectionKeys.length; i++) {
          if (i == index) continue;
          final state = sectionKeys[i].currentState;
          if (state == null) continue;
          try {
            (state as dynamic).collapse();
          } catch (_) {}
        }
      });
    }

    final topPadding =
        context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;
    final isDesktop = GetPlatform.isDesktop;
    return Padding(
      padding: isBottomNavActive
          ? EdgeInsets.only(
              left: kContentLeftPaddingWithBottomNav,
              top: topPadding,
              right: kContentRightPaddingSettingsWithBottomNav)
          : EdgeInsets.only(
              top: topPadding,
              left: kContentLeftPaddingWithoutBottomNav,
              right: kContentLeftPaddingWithoutBottomNav),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Text(
              "settings".tr,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
          Expanded(
              child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
                bottom: kSettingsListBottomPadding + 20,
                top: kSettingsListTopPadding),
            children: [
              Obx(
                () => settingsController.isNewVersionAvailable.value
                    ? Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, right: 8, bottom: 16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              onTap: () {
                                launchUrl(
                                  Uri.parse('https://openlyst.ink/'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.download,
                                      color: Colors.white)),
                              title: Text("newVersionAvailable".tr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              visualDensity:
                                  const VisualDensity(horizontal: -2),
                              subtitle: Text(
                                "goToDownloadPage".tr,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                        fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              SettingsPersonalisationSection(
                expansionKey: sectionKeys[0],
                onExpansionChanged: (expanded) =>
                    handleSectionExpansion(0, expanded),
                onThemeTap: () => showDialog(
                  context: context,
                  builder: (context) => const ThemeSelectorDialog(),
                ),
              ),
              CustomExpansionTile(
                  title: "content".tr,
                  icon: Icons.movie_outlined,
                  expansionKey: sectionKeys[1],
                  onExpansionChanged: (expanded) =>
                      handleSectionExpansion(1, expanded),
                  children: [
                    Obx(() {
                      final isYt = settingsController.activeServer?.type ==
                          ServerType.youtubeMusic;
                      if (!isYt) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("setDiscoverContent".tr),
                        subtitle: Obx(() => Text(
                            settingsController.discoverContentType.value == "QP"
                                ? "quickpicks".tr
                                : settingsController
                                            .discoverContentType.value ==
                                        "TMV"
                                    ? "topmusicvideos".tr
                                    : settingsController
                                                .discoverContentType.value ==
                                            "TR"
                                        ? "trending".tr
                                        : "basedOnLast".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ))),
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) =>
                              const DiscoverContentSelectorDialog(),
                        ),
                      );
                    }),
                    Obx(() {
                      final isYt = settingsController.activeServer?.type ==
                          ServerType.youtubeMusic;
                      if (!isYt) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("homeContentCount".tr),
                        subtitle: Text("homeContentCountDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => DropdownButton(
                            dropdownColor: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            underline: const SizedBox.shrink(),
                            value:
                                settingsController.noOfHomeScreenContent.value,
                            items: ([3, 5, 7, 9, 11])
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text("$e")))
                                .toList(),
                            onChanged: settingsController.setContentNumber,
                          ),
                        ),
                      );
                    }),
                    if (isDesktop)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("sidebarMode".tr),
                        subtitle: Text(
                          "sidebarModeDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                        ),
                        trailing: Obx(
                          () => DropdownButton<SidebarMode>(
                            dropdownColor: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            underline: const SizedBox.shrink(),
                            value: settingsController.sidebarMode.value,
                            items: [
                              DropdownMenuItem(
                                value: SidebarMode.auto,
                                child: Text("sidebarModeAuto".tr),
                              ),
                              DropdownMenuItem(
                                value: SidebarMode.collapsed,
                                child: Text("sidebarModeCollapsed".tr),
                              ),
                              DropdownMenuItem(
                                value: SidebarMode.expanded,
                                child: Text("sidebarModeExpanded".tr),
                              ),
                            ],
                            onChanged: settingsController.setSidebarMode,
                          ),
                        ),
                      ),
                    ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("cacheHomeScreenData".tr),
                        subtitle: Text("cacheHomeScreenDataDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => CustSwitch(
                              value:
                                  settingsController.cacheHomeScreenData.value,
                              onChanged:
                                  settingsController.toggleCacheHomeScreenData),
                        )),
                    Obx(() {
                      final isYt = settingsController.activeServer?.type ==
                          ServerType.youtubeMusic;
                      if (!isYt) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("Piped".tr),
                        subtitle: Text("linkPipedDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: TextButton(
                            child: Obx(() => Text(
                                  settingsController.isLinkedWithPiped.value
                                      ? "unLink".tr
                                      : "link".tr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                )),
                            onPressed: () {
                              if (settingsController
                                  .isLinkedWithPiped.isFalse) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const LinkPiped(),
                                ).whenComplete(
                                    () => Get.delete<PipedLinkedController>());
                              } else {
                                settingsController.unlinkPiped();
                              }
                            }),
                      );
                    }),
                    Obx(() {
                      final isYt = settingsController.activeServer?.type ==
                          ServerType.youtubeMusic;
                      if (!isYt ||
                          !settingsController.isLinkedWithPiped.isTrue) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("resetblacklistedplaylist".tr),
                        subtitle: Text("resetblacklistedplaylistDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: TextButton(
                            child: Text(
                              "reset".tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await Get.find<LibraryPlaylistsController>()
                                  .resetBlacklistedPlaylist();
                              ScaffoldMessenger.of(Get.context!).showSnackBar(
                                  snackbar(Get.context!,
                                      "blacklistPlstResetAlert".tr,
                                      size: SnackBarSize.MEDIUM));
                            }),
                      );
                    }),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("clearImgCache".tr),
                      subtitle: Text(
                        "clearImgCacheDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      onTap: () {
                        settingsController.clearImagesCache().then((value) =>
                            ScaffoldMessenger.of(Get.context!).showSnackBar(
                                snackbar(Get.context!, "clearImgCacheAlert".tr,
                                    size: SnackBarSize.BIG)));
                      },
                    ),
                  ]),
              CustomExpansionTile(
                title: "music&Playback".tr,
                icon: Icons.music_note_outlined,
                expansionKey: sectionKeys[2],
                onExpansionChanged: (expanded) =>
                    handleSectionExpansion(2, expanded),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text("streamingQuality".tr),
                    subtitle: Text("streamingQualityDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            )),
                    trailing: Obx(
                      () => DropdownButton(
                        dropdownColor: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        underline: const SizedBox.shrink(),
                        value: settingsController.streamingQuality.value,
                        items: [
                          DropdownMenuItem(
                              value: AudioQuality.Low, child: Text("low".tr)),
                          DropdownMenuItem(
                            value: AudioQuality.High,
                            child: Text("high".tr),
                          ),
                        ],
                        onChanged: settingsController.setStreamingQuality,
                      ),
                    ),
                  ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("loudnessNormalization".tr),
                        subtitle: Text("loudnessNormalizationDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .loudnessNormalizationEnabled.value,
                              onChanged: settingsController
                                  .toggleLoudnessNormalization),
                        )),
                  if (!isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("cacheSongs".tr),
                        subtitle: Text("cacheSongsDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController.cacheSongs.value,
                              onChanged:
                                  settingsController.toggleCachingSongsValue),
                        )),
                  if (!isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("skipSilence".tr),
                        subtitle: Text("skipSilenceDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => CustSwitch(
                              value:
                                  settingsController.skipSilenceEnabled.value,
                              onChanged: settingsController.toggleSkipSilence),
                        )),
                  if (isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("backgroundPlay".tr),
                        subtitle: Text("backgroundPlayDes".tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .backgroundPlayEnabled.value,
                              onChanged:
                                  settingsController.toggleBackgroundPlay),
                        )),
                  ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("keepScreenOnWhilePlaying".tr),
                      subtitle: Text("keepScreenOnWhilePlayingDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  )),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.keepScreenAwake.value,
                            onChanged:
                                settingsController.toggleKeepScreenAwake),
                      )),
                  ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("restoreLastPlaybackSession".tr),
                      subtitle: Text("restoreLastPlaybackSessionDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  )),
                      trailing: Obx(
                        () => CustSwitch(
                            value:
                                settingsController.restorePlaybackSession.value,
                            onChanged: settingsController
                                .toggleRestorePlaybackSession),
                      )),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text("autoOpenPlayer".tr),
                    subtitle: Text("autoOpenPlayerDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            )),
                    trailing: Obx(
                      () => CustSwitch(
                          value: settingsController.autoOpenPlayer.value,
                          onChanged: settingsController.toggleAutoOpenPlayer),
                    ),
                  ),
                  if (!isDesktop)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("equalizer".tr),
                      subtitle: Text("equalizerDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  )),
                      onTap: () async {
                        try {
                          await Get.find<PlayerController>().openEqualizer();
                        } catch (e) {
                          printERROR(e);
                        }
                      },
                    ),
                  if (!isDesktop)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("stopMusicOnTaskClear".tr),
                      subtitle: Text("stopMusicOnTaskClearDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  )),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .stopPlyabackOnSwipeAway.value,
                            onChanged: settingsController
                                .toggleStopPlyabackOnSwipeAway),
                      ),
                    ),
                  GetPlatform.isAndroid
                      ? Obx(
                          () => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: Text("ignoreBatOpt".tr),
                            onTap: settingsController
                                    .isIgnoringBatteryOptimizations.isFalse
                                ? settingsController
                                    .enableIgnoringBatteryOptimizations
                                : null,
                            subtitle: Obx(() => RichText(
                                  text: TextSpan(
                                    text:
                                        "${"status".tr}: ${settingsController.isIgnoringBatteryOptimizations.isTrue ? "enabled".tr : "disabled".tr}\n",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color),
                                    children: <TextSpan>[
                                      TextSpan(
                                          text: "ignoreBatOptDes".tr,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                              )),
                                    ],
                                  ),
                                )),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
              CustomExpansionTile(
                title: "servers".tr,
                icon: Icons.dns_outlined,
                expansionKey: sectionKeys[3],
                onExpansionChanged: (expanded) =>
                    handleSectionExpansion(3, expanded),
                children: [
                  Obx(() {
                    final servers = settingsController.servers;
                    final activeId = settingsController.activeServerId.value;
                    if (servers.isEmpty) {
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text("noServersConfigured".tr),
                      );
                    }
                    return Column(
                      children: [
                        ...servers.map(
                          (server) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            leading: Icon(
                              _serverIcon(server.type),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                    child: Text(server.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                if (server.isDefault)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'default'.tr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              server.isDefault
                                  ? _serverTypeLabelText(server.type).tr
                                  : (server.serverUrl != null &&
                                          server.serverUrl!.isNotEmpty
                                      ? server.serverUrl!
                                      : _serverTypeLabelText(server.type).tr),
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<int>(
                                  value: server.id,
                                  groupValue: activeId,
                                  onChanged: (val) {
                                    if (val != null) {
                                      settingsController.setActiveServer(val);
                                    }
                                  },
                                ),
                                if (!server.isDefault) ...[
                                  if (server.type != ServerType.youtubeMusic)
                                    IconButton(
                                      icon:
                                          const Icon(Icons.wifi_find, size: 20),
                                      tooltip: "testConnection".tr,
                                      onPressed: () async {
                                        final err = await settingsController
                                            .testServerConnection(server);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(err == null
                                              ? "connectionSuccess".tr
                                              : "${"connectionFailed".tr}: $err"),
                                        ));
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => AddServerDialog(
                                        serverType: server.type,
                                        existing: server,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    onPressed: () => settingsController
                                        .removeServer(server.id),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Divider(indent: 12, endIndent: 12),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 12, right: 12, top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "activeServer".tr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 12, right: 12, top: 4, bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              servers
                                      .firstWhereOrNull((s) => s.id == activeId)
                                      ?.name ??
                                  "none".tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Obx(() {
                          final active = settingsController.activeServer;
                          final isNonYouTube = active != null &&
                              active.type != ServerType.youtubeMusic;
                          if (!isNonYouTube) return const SizedBox.shrink();

                          String buildKindStatus(LibraryKind kind) {
                            final isSyncing =
                                syncService.isSyncingByKind[kind] == true;
                            final err = syncService.lastErrorByKind[kind] ?? '';
                            final ts = syncService.lastSuccessMsByKind[kind];
                            if (isSyncing) return "${kind.name}: syncing...";
                            if (err.isNotEmpty) {
                              return "${kind.name}: error";
                            }
                            if (ts == null) return "${kind.name}: never";
                            final syncText =
                                DateTime.fromMillisecondsSinceEpoch(ts)
                                    .toLocal()
                                    .toString()
                                    .split('.')
                                    .first;
                            return "${kind.name}: $syncText";
                          }

                          final subtitle = [
                            buildKindStatus(LibraryKind.songs),
                            buildKindStatus(LibraryKind.playlists),
                            buildKindStatus(LibraryKind.albums),
                            buildKindStatus(LibraryKind.artists),
                          ].join("\\n");

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text("Resync Library Now"),
                            subtitle: Text(
                              syncService.lastError.value.isEmpty
                                  ? subtitle
                                  : "$subtitle\nError: ${syncService.lastError.value}",
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                            ),
                            trailing: TextButton(
                              onPressed: syncService.isSyncing.value
                                  ? null
                                  : () async {
                                      await settingsController
                                          .resyncLibraryNow();
                                      if (!context.mounted) return;
                                      final failed = LibraryKind.values.any(
                                          (k) =>
                                              (syncService.lastErrorByKind[k] ??
                                                      '')
                                                  .isNotEmpty);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            failed
                                                ? "Library sync failed"
                                                : "Library sync completed",
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                syncService.isSyncing.value
                                    ? "Syncing..."
                                    : "Sync",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => const AddServerDialog(
                                    serverType: ServerType.youtubeMusic,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.play_circle_outline,
                                    size: 18),
                                label: Text("youtubeMusic".tr,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => const AddServerDialog(
                                    serverType: ServerType.subsonic,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.waves, size: 18),
                                label: Text("subsonic".tr,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => const AddServerDialog(
                                    serverType: ServerType.jellyfin,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.tv, size: 18),
                                label: Text("jellyfin".tr,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => const AddServerDialog(
                                    serverType: ServerType.plex,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon:
                                    const Icon(Icons.cloud_outlined, size: 18),
                                label: Text("plex".tr,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                ],
              ),
              CustomExpansionTile(
                title: "download".tr,
                icon: Icons.download_outlined,
                expansionKey: sectionKeys[4],
                onExpansionChanged: (expanded) =>
                    handleSectionExpansion(4, expanded),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text("autoDownFavSong".tr),
                    subtitle: Text("autoDownFavSongDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            )),
                    trailing: Obx(
                      () => CustSwitch(
                          value: settingsController
                              .autoDownloadFavoriteSongEnabled.value,
                          onChanged: settingsController
                              .toggleAutoDownloadFavoriteSong),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text("downloadingFormat".tr),
                    subtitle: Text("downloadingFormatDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            )),
                    trailing: Obx(
                      () => DropdownButton(
                        dropdownColor: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        underline: const SizedBox.shrink(),
                        value: settingsController.downloadingFormat.value,
                        items: const [
                          DropdownMenuItem(
                              value: "opus", child: Text("Opus/Ogg")),
                          DropdownMenuItem(
                            value: "m4a",
                            child: Text("M4a"),
                          ),
                        ],
                        onChanged: settingsController.changeDownloadingFormat,
                      ),
                    ),
                  ),
                  ListTile(
                    trailing: TextButton(
                      child: Text(
                        "reset".tr,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                                fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        settingsController.resetDownloadLocation();
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text("downloadLocation".tr),
                    subtitle: Obx(() => Text(
                        settingsController.isCurrentPathsupportDownDir
                            ? "In App storage directory"
                            : settingsController.downloadLocationPath.value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ))),
                    onTap: () async {
                      settingsController.setDownloadLocation();
                    },
                  ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("exportDowloadedFiles".tr),
                      subtitle: Text(
                        "exportDowloadedFilesDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const ExportFileDialog(),
                      ).whenComplete(
                          () => Get.delete<ExportFileDialogController>()),
                    ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("exportedFileLocation".tr),
                      subtitle: Obx(() => Text(
                          settingsController.exportLocationPath.value,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ))),
                      onTap: () async {
                        settingsController.setExportedLocation();
                      },
                    ),
                ],
              ),
              CustomExpansionTile(
                  title: "${"backup".tr} & ${"restore".tr}",
                  icon: Icons.restore_outlined,
                  expansionKey: sectionKeys[5],
                  onExpansionChanged: (expanded) =>
                      handleSectionExpansion(5, expanded),
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("backupAppData".tr),
                      subtitle: Text(
                        "backupSettingsAndPlaylistsDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const BackupDialog(),
                      ).whenComplete(
                          () => Get.delete<BackupDialogController>()),
                    ),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("restoreAppData".tr),
                      subtitle: Text(
                        "restoreSettingsAndPlaylistsDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const RestoreDialog(),
                      ).whenComplete(
                          () => Get.delete<RestoreDialogController>()),
                    ),
                  ]),
              CustomExpansionTile(
                  icon: Icons.miscellaneous_services_outlined,
                  title: "misc".tr,
                  expansionKey: sectionKeys[6],
                  onExpansionChanged: (expanded) =>
                      handleSectionExpansion(6, expanded),
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text("resetToDefault".tr),
                      subtitle: Text(
                        "resetToDefaultDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      onTap: () {
                        settingsController
                            .resetAppSettingsToDefault()
                            .then((_) {
                          ScaffoldMessenger.of(Get.context!).showSnackBar(
                              snackbar(Get.context!, "resetToDefaultMsg".tr,
                                  size: SnackBarSize.BIG,
                                  duration: const Duration(seconds: 2)));
                        });
                      },
                    ),
                  ]),
              CustomExpansionTile(
                icon: Icons.info_outline,
                title: "appInfo".tr,
                expansionKey: sectionKeys[7],
                onExpansionChanged: (expanded) =>
                    handleSectionExpansion(7, expanded),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.system_update_alt, size: 20),
                    title: Text("checkForUpdatesOnStartup".tr),
                    trailing: Obx(
                      () => CustSwitch(
                        value:
                            settingsController.checkForUpdatesOnStartup.value,
                        onChanged:
                            settingsController.toggleCheckForUpdatesOnStartup,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.system_update, size: 20),
                    title: Text("checkForUpdates".tr),
                    onTap: () async {
                      final upToDate = "upToDate".tr;
                      final checking = "checkingForUpdates".tr;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(checking)),
                      );
                      final info = await PackageInfo.fromPlatform();
                      final latest = await newVersionCheck(info.version);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      if (latest != null) {
                        Get.find<SettingsScreenController>()
                            .latestAvailableVersion
                            .value = latest;
                        Get.find<SettingsScreenController>()
                            .isNewVersionAvailable
                            .value = true;
                        showDialog(
                          context: context,
                          builder: (_) =>
                              NewVersionDialog(latestVersion: latest),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(upToDate)),
                        );
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.language, size: 20),
                    title: Text("openOpenlystWebsite".tr),
                    onTap: () {
                      launchUrl(
                        Uri.parse('https://openlyst.ink/'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.code, size: 20),
                    title: Text("openGitlab".tr),
                    subtitle: Text(
                      "gitlabDes".tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      launchUrl(
                        Uri.parse('https://gitlab.com/Openlyst/doudou/'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  const Divider(indent: 12, endIndent: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          "Doudou",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(settingsController.currentVersion,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color))
                      ],
                    ),
                  ),
                ],
              )
            ],
          )),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
              child: Text(
                "${settingsController.currentVersion} ${"by".tr} openlyst",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "themeMode".tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    radioWidget(
                      label: "dynamic".tr,
                      controller: settingsController,
                      value: ThemeType.dynamic,
                    ),
                    radioWidget(
                      label: "dynamicColor".tr,
                      controller: settingsController,
                      value: ThemeType.dynamicColor,
                    ),
                    radioWidget(
                        label: "systemDefault".tr,
                        controller: settingsController,
                        value: ThemeType.system),
                    radioWidget(
                        label: "dark".tr,
                        controller: settingsController,
                        value: ThemeType.dark),
                    radioWidget(
                        label: "oled".tr,
                        controller: settingsController,
                        value: ThemeType.oled),
                    radioWidget(
                        label: "light".tr,
                        controller: settingsController,
                        value: ThemeType.light),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("cancel".tr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
            )
          ],
        ),
      ),
    );
  }
}

class DiscoverContentSelectorDialog extends StatelessWidget {
  const DiscoverContentSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "setDiscoverContent".tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    radioWidget(
                        label: "quickpicks".tr,
                        controller: settingsController,
                        value: "QP"),
                    radioWidget(
                        label: "topmusicvideos".tr,
                        controller: settingsController,
                        value: "TMV"),
                    radioWidget(
                        label: "trending".tr,
                        controller: settingsController,
                        value: "TR"),
                    radioWidget(
                        label: "basedOnLast".tr,
                        controller: settingsController,
                        value: "BOLI"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("cancel".tr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
            )
          ],
        ),
      ),
    );
  }
}

class AddServerDialog extends StatefulWidget {
  const AddServerDialog({
    super.key,
    required this.serverType,
    this.existing,
  });

  final ServerType serverType;
  final SettingsServer? existing;

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: widget.existing?.serverUrl ?? '');
    _usernameController =
        TextEditingController(text: widget.existing?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.existing?.password ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _needsCredentials =>
      widget.serverType == ServerType.subsonic ||
      widget.serverType == ServerType.jellyfin ||
      widget.serverType == ServerType.plex;

  String get _titleKey {
    if (widget.existing != null) return 'editServer'.tr;
    switch (widget.serverType) {
      case ServerType.youtubeMusic:
        return '${'addServer'.tr} - ${'youtubeMusic'.tr}';
      case ServerType.subsonic:
        return '${'addServer'.tr} - ${'subsonic'.tr}';
      case ServerType.jellyfin:
        return '${'addServer'.tr} - ${'jellyfin'.tr}';
      case ServerType.plex:
        return '${'addServer'.tr} - ${'plex'.tr}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _titleKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_needsCredentials) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'serverUrl'.tr,
                  hintText: 'https://example.com',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              if (widget.serverType != ServerType.plex) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'username'.tr),
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: widget.serverType == ServerType.plex
                      ? 'plexToken'.tr
                      : 'password'.tr,
                ),
                obscureText: true,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'youtubeMusicNoLogin'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (widget.existing != null) {
                      if (_needsCredentials) {
                        controller.updateServer(
                          widget.existing!.id,
                          serverUrl: _urlController.text,
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      }
                    } else {
                      if (_needsCredentials) {
                        if (_urlController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('serverUrlRequired'.tr)),
                          );
                          return;
                        }
                        controller.addServerWithCredentials(
                          widget.serverType,
                          serverUrl: _urlController.text,
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      } else {
                        controller
                            .addServerWithCredentials(ServerType.youtubeMusic);
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(widget.existing != null ? 'save'.tr : 'add'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget radioWidget(
    {required String label,
    required SettingsScreenController controller,
    required value}) {
  return Obx(() => ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        onTap: () {
          if (value.runtimeType == ThemeType) {
            controller.onThemeChange(value);
          } else {
            controller.onContentChange(value);
            Navigator.of(Get.context!).pop();
          }
        },
        leading: RadioGroup<dynamic>(
            groupValue: value.runtimeType == ThemeType
                ? controller.themeModetype.value
                : controller.discoverContentType.value,
            onChanged: value.runtimeType == ThemeType
                ? controller.onThemeChange
                : (v) {
                    controller.onContentChange(v);
                    Navigator.of(Get.context!).pop();
                  },
            child: Radio(value: value)),
        title: Text(label),
      ));
}

IconData _serverIcon(ServerType type) {
  switch (type) {
    case ServerType.youtubeMusic:
      return Icons.play_circle_outline;
    case ServerType.subsonic:
      return Icons.waves;
    case ServerType.jellyfin:
      return Icons.tv;
    case ServerType.plex:
      return Icons.cloud;
  }
}

String _serverTypeLabelText(ServerType type) {
  switch (type) {
    case ServerType.youtubeMusic:
      return "youtubeMusic";
    case ServerType.subsonic:
      return "subsonic";
    case ServerType.jellyfin:
      return "jellyfin";
    case ServerType.plex:
      return "plex";
  }
}
