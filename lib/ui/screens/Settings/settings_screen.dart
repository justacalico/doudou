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
import '/utils/lang_mapping.dart';
import '/models/server.dart';
import 'settings_screen_controller.dart';

class SettingsScreen extends GetView<SettingsScreenController> {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    return _IOSSettingsView(isBottomNavActive: isBottomNavActive);
  }
}

enum _SettingsSectionId {
  personalisation,
  content,
  playback,
  servers,
  download,
  backup,
  misc,
  info,
}

class _SettingsCluster {
  const _SettingsCluster({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<_SettingsSectionId> sections;
}

class _IOSSettingsView extends StatefulWidget {
  const _IOSSettingsView({required this.isBottomNavActive});

  final bool isBottomNavActive;

  @override
  State<_IOSSettingsView> createState() => _IOSSettingsViewState();
}

class _IOSSettingsViewState extends State<_IOSSettingsView> {
  _SettingsSectionId _selected = _SettingsSectionId.personalisation;

  static const _sectionMeta = <(_SettingsSectionId, IconData, String)>[
    (
      _SettingsSectionId.personalisation,
      Icons.palette_outlined,
      "personalisation"
    ),
    (_SettingsSectionId.content, Icons.movie_outlined, "content"),
    (_SettingsSectionId.playback, Icons.music_note_outlined, "music&Playback"),
    (_SettingsSectionId.servers, Icons.dns_outlined, "servers"),
    (_SettingsSectionId.download, Icons.download_outlined, "download"),
    (_SettingsSectionId.backup, Icons.restore_outlined, "backup"),
    (_SettingsSectionId.misc, Icons.miscellaneous_services_outlined, "misc"),
    (_SettingsSectionId.info, Icons.info_outline, "appInfo"),
  ];

  static const _mobileClusters = <_SettingsCluster>[
    _SettingsCluster(
      title: 'ACCOUNTS',
      sections: [
        _SettingsSectionId.servers,
        _SettingsSectionId.backup,
      ],
    ),
    _SettingsCluster(
      title: 'USER',
      sections: [
        _SettingsSectionId.content,
        _SettingsSectionId.playback,
        _SettingsSectionId.misc,
      ],
    ),
    _SettingsCluster(
      title: 'APPEARANCE',
      sections: [
        _SettingsSectionId.personalisation,
        _SettingsSectionId.download,
        _SettingsSectionId.info,
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsScreenController>();
    final syncService = Get.find<LibrarySyncService>();
    final topPadding =
        context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;
    final isDesktop = GetPlatform.isDesktop;
    final useTwoPane = isDesktop && MediaQuery.sizeOf(context).width >= 980;

    final outerPadding = widget.isBottomNavActive
        ? EdgeInsets.only(
            left: kContentLeftPaddingWithBottomNav,
            top: topPadding,
            right: kContentRightPaddingSettingsWithBottomNav,
          )
        : EdgeInsets.only(
            top: topPadding,
            left: kContentLeftPaddingWithoutBottomNav,
            right: kContentLeftPaddingWithoutBottomNav,
          );

    const accent = Color(0xFFE0E0E0);
    const panel = Color(0xFF0A0A0A);
    const panelSoft = Color(0xFF111111);
    const line = Color(0xFF232323);

    return Padding(
      padding: outerPadding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: line),
          gradient: const LinearGradient(
            colors: [panel, Color(0xFF070707)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Row(
                  children: [
                    if (useTwoPane)
                      const Icon(Icons.settings_outlined,
                          color: Colors.white70, size: 18),
                    if (useTwoPane) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "settings".tr,
                        textAlign:
                            useTwoPane ? TextAlign.left : TextAlign.center,
                        style: (useTwoPane
                                ? Theme.of(context).textTheme.headlineSmall
                                : Theme.of(context).textTheme.titleLarge)
                            ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: useTwoPane
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 310,
                            child: _buildSectionNav(context),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_selected),
                                child: _buildSingleSection(
                                    context, settings, syncService, _selected),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildMobileSectionList(context, settings, syncService),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 14),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: panelSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: line),
                ),
                child: Text(
                  "${settings.currentVersion} ${"by".tr} openlyst",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accent.withValues(alpha: 0.75),
                        letterSpacing: 0.4,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF252525)),
      ),
      child: ListView(
        children: [
          for (final cluster in _mobileClusters) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
              child: Text(
                cluster.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
              ),
            ),
            ...cluster.sections.map((id) {
              final (sectionId, icon, titleKey) =
                  _sectionMeta.firstWhere((e) => e.$1 == id);
              final selected = sectionId == _selected;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFF0C0C0C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.40)
                        : const Color(0xFF202020),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => setState(() => _selected = sectionId),
                  leading: Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.76),
                  ),
                  title: Text(
                    titleKey.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  trailing: selected
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.6)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileSectionList(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _mobileClusters.length,
      itemBuilder: (context, clusterIndex) {
        final cluster = _mobileClusters[clusterIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(10, clusterIndex == 0 ? 2 : 14, 10, 8),
              child: Text(
                cluster.title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF242424)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < cluster.sections.length; i++) ...[
                    _buildMobileSectionRow(
                      context,
                      settings,
                      syncService,
                      cluster.sections[i],
                    ),
                    if (i < cluster.sections.length - 1)
                      Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 12,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileSectionRow(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
    _SettingsSectionId id,
  ) {
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    final badge = _sectionBadge(id);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          meta.$2,
          size: 18,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
      title: Text(
        meta.$3.tr,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
      ),
      subtitle: Text(
        _sectionSubtitle(id),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
      ),
      trailing: badge == null
          ? Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.6))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
      onTap: () => _openSectionSubPage(context, settings, syncService, id),
    );
  }

  String _sectionSubtitle(_SettingsSectionId id) {
    return switch (id) {
      _SettingsSectionId.servers => "servers".tr,
      _SettingsSectionId.backup => "backupSettingsAndPlaylistsDes".tr,
      _SettingsSectionId.content => "content".tr,
      _SettingsSectionId.playback => "music&Playback".tr,
      _SettingsSectionId.misc => "misc".tr,
      _SettingsSectionId.personalisation => "themeMode".tr,
      _SettingsSectionId.download => "download".tr,
      _SettingsSectionId.info => "appInfo".tr,
    };
  }

  String? _sectionBadge(_SettingsSectionId id) {
    return switch (id) {
      _SettingsSectionId.servers => 'Active',
      _SettingsSectionId.personalisation => 'Theme',
      _SettingsSectionId.playback => 'Audio',
      _SettingsSectionId.download => 'Files',
      _ => null,
    };
  }

  void _openSectionSubPage(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
    _SettingsSectionId id,
  ) {
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsSubPage(
          icon: meta.$2,
          title: meta.$3.tr,
          children: _buildSectionChildren(context, settings, syncService, id),
        ),
      ),
    );
  }

  Widget _buildSingleSection(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
    _SettingsSectionId id,
  ) {
    final children = _buildSectionChildren(context, settings, syncService, id);
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    return _SettingsCard(
      icon: meta.$2,
      title: meta.$3.tr,
      children: children,
    );
  }

  List<Widget> _buildSectionChildren(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
    _SettingsSectionId id,
  ) {
    return switch (id) {
      _SettingsSectionId.personalisation =>
        _buildPersonalisation(context, settings),
      _SettingsSectionId.content => _buildContent(context, settings),
      _SettingsSectionId.playback => _buildPlayback(context, settings),
      _SettingsSectionId.servers =>
        _buildServers(context, settings, syncService),
      _SettingsSectionId.download => _buildDownload(context, settings),
      _SettingsSectionId.backup => _buildBackup(context),
      _SettingsSectionId.misc => _buildMisc(context, settings),
      _SettingsSectionId.info => _buildInfo(context, settings),
    };
  }

  List<Widget> _buildPersonalisation(
      BuildContext context, SettingsScreenController settings) {
    final isDesktop = GetPlatform.isDesktop;
    return [
      ListTile(
        title: Text("themeMode".tr),
        subtitle: Obx(() => Text(
              settings.themeModetype.value == ThemeType.dynamic
                  ? "dynamic".tr
                  : settings.themeModetype.value == ThemeType.system
                      ? "systemDefault".tr
                      : settings.themeModetype.value == ThemeType.dark
                          ? "dark".tr
                          : settings.themeModetype.value == ThemeType.oled
                              ? "oled".tr
                              : "light".tr,
            )),
        onTap: () => showDialog(
          context: context,
          builder: (context) => const ThemeSelectorDialog(),
        ),
      ),
      Obx(() => ListTile(
            title: Text("lyricsDynamicColor".tr),
            subtitle: Text("lyricsDynamicColorDes".tr),
            trailing: CustSwitch(
              value: settings.lyricsDynamicColorEnabled.value,
              onChanged: settings.setLyricsDynamicColorEnabled,
            ),
          )),
      ListTile(
        title: Text("syncedLyricsHighlightStyle".tr),
        subtitle: Text("syncedLyricsHighlightStyleDes".tr),
        trailing: Obx(
          () => DropdownButton<SyncedLyricsHighlightStyle>(
            value: settings.syncedLyricsHighlightStyle.value,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: SyncedLyricsHighlightStyle.block,
                child: Text("lyricsHighlightBlock".tr),
              ),
              DropdownMenuItem(
                value: SyncedLyricsHighlightStyle.karaoke,
                child: Text("lyricsHighlightKaraoke".tr),
              ),
            ],
            onChanged: (v) {
              if (v != null) settings.setSyncedLyricsHighlightStyle(v);
            },
          ),
        ),
      ),
      ListTile(
        title: Text("language".tr),
        subtitle: Text("languageDes".tr),
        trailing: Obx(
          () => DropdownButton(
            menuMaxHeight: Get.height - 250,
            underline: const SizedBox.shrink(),
            value: settings.currentAppLanguageCode.value,
            items: langMap.entries
                .map((lang) =>
                    DropdownMenuItem(value: lang.key, child: Text(lang.value)))
                .whereType<DropdownMenuItem<String>>()
                .toList(),
            onChanged: settings.setAppLanguage,
          ),
        ),
      ),
      if (!isDesktop)
        ListTile(
          title: Text("playerUi".tr),
          subtitle: Text("playerUiDes".tr),
          trailing: Obx(
            () => DropdownButton(
              underline: const SizedBox.shrink(),
              value: settings.playerUi.value,
              items: [
                DropdownMenuItem(value: 0, child: Text("standard".tr)),
                DropdownMenuItem(value: 1, child: Text("gesture".tr)),
              ],
              onChanged: settings.setPlayerUi,
            ),
          ),
        ),
      ListTile(
        title: Text("animationSpeed".tr),
        subtitle: Text("animationSpeedDes".tr),
        trailing: Obx(
          () => DropdownButton<AnimationSpeed>(
            underline: const SizedBox.shrink(),
            value: settings.animationSpeed.value,
            items: [
              DropdownMenuItem(
                  value: AnimationSpeed.off,
                  child: Text("animationSpeedOff".tr)),
              DropdownMenuItem(
                  value: AnimationSpeed.fast,
                  child: Text("animationSpeedFast".tr)),
              DropdownMenuItem(
                  value: AnimationSpeed.normal,
                  child: Text("animationSpeedNormal".tr)),
              DropdownMenuItem(
                  value: AnimationSpeed.slow,
                  child: Text("animationSpeedSlow".tr)),
            ],
            onChanged: (v) {
              if (v != null) settings.setAnimationSpeed(v);
            },
          ),
        ),
      ),
      Obx(() => ListTile(
            title: Text("enableSlidableAction".tr),
            subtitle: Text("enableSlidableActionDes".tr),
            trailing: CustSwitch(
              value: settings.slidableActionEnabled.value,
              onChanged: settings.toggleSlidableAction,
            ),
          )),
    ];
  }

  List<Widget> _buildContent(
      BuildContext context, SettingsScreenController settings) {
    final isDesktop = GetPlatform.isDesktop;
    return [
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return ListTile(
          title: Text("setDiscoverContent".tr),
          subtitle: Text(
            settings.discoverContentType.value == "QP"
                ? "quickpicks".tr
                : settings.discoverContentType.value == "TMV"
                    ? "topmusicvideos".tr
                    : settings.discoverContentType.value == "TR"
                        ? "trending".tr
                        : "basedOnLast".tr,
          ),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const DiscoverContentSelectorDialog(),
          ),
        );
      }),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return ListTile(
          title: Text("homeContentCount".tr),
          subtitle: Text("homeContentCountDes".tr),
          trailing: DropdownButton(
            underline: const SizedBox.shrink(),
            value: settings.noOfHomeScreenContent.value,
            items: ([3, 5, 7, 9, 11])
                .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
                .toList(),
            onChanged: settings.setContentNumber,
          ),
        );
      }),
      if (isDesktop)
        ListTile(
          title: Text("sidebarMode".tr),
          subtitle: Text("sidebarModeDes".tr),
          trailing: Obx(
            () => DropdownButton<SidebarMode>(
              underline: const SizedBox.shrink(),
              value: settings.sidebarMode.value,
              items: [
                DropdownMenuItem(
                    value: SidebarMode.auto, child: Text("sidebarModeAuto".tr)),
                DropdownMenuItem(
                    value: SidebarMode.collapsed,
                    child: Text("sidebarModeCollapsed".tr)),
                DropdownMenuItem(
                    value: SidebarMode.expanded,
                    child: Text("sidebarModeExpanded".tr)),
              ],
              onChanged: settings.setSidebarMode,
            ),
          ),
        ),
      Obx(() => ListTile(
            title: Text("cacheHomeScreenData".tr),
            subtitle: Text("cacheHomeScreenDataDes".tr),
            trailing: CustSwitch(
              value: settings.cacheHomeScreenData.value,
              onChanged: settings.toggleCacheHomeScreenData,
            ),
          )),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return ListTile(
          title: Text("Piped".tr),
          subtitle: Text("linkPipedDes".tr),
          trailing: TextButton(
            onPressed: () {
              if (settings.isLinkedWithPiped.isFalse) {
                showDialog(context: context, builder: (_) => const LinkPiped())
                    .whenComplete(() => Get.delete<PipedLinkedController>());
              } else {
                settings.unlinkPiped();
              }
            },
            child: Text(
                settings.isLinkedWithPiped.value ? "unLink".tr : "link".tr),
          ),
        );
      }),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt || !settings.isLinkedWithPiped.value) {
          return const SizedBox.shrink();
        }
        return ListTile(
          title: Text("resetblacklistedplaylist".tr),
          subtitle: Text("resetblacklistedplaylistDes".tr),
          trailing: TextButton(
            onPressed: () async {
              await Get.find<LibraryPlaylistsController>()
                  .resetBlacklistedPlaylist();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                snackbar(context, "blacklistPlstResetAlert".tr,
                    size: SnackBarSize.MEDIUM),
              );
            },
            child: Text("reset".tr),
          ),
        );
      }),
      ListTile(
        title: Text("clearImgCache".tr),
        subtitle: Text("clearImgCacheDes".tr),
        onTap: () async {
          await settings.clearImagesCache();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, "clearImgCacheAlert".tr, size: SnackBarSize.BIG),
          );
        },
      ),
    ];
  }

  List<Widget> _buildPlayback(
      BuildContext context, SettingsScreenController settings) {
    final isDesktop = GetPlatform.isDesktop;
    return [
      ListTile(
        title: Text("streamingQuality".tr),
        subtitle: Text("streamingQualityDes".tr),
        trailing: Obx(
          () => DropdownButton(
            underline: const SizedBox.shrink(),
            value: settings.streamingQuality.value,
            items: [
              DropdownMenuItem(value: AudioQuality.Low, child: Text("low".tr)),
              DropdownMenuItem(
                  value: AudioQuality.High, child: Text("high".tr)),
            ],
            onChanged: settings.setStreamingQuality,
          ),
        ),
      ),
      if (GetPlatform.isAndroid)
        Obx(() => ListTile(
              title: Text("loudnessNormalization".tr),
              subtitle: Text("loudnessNormalizationDes".tr),
              trailing: CustSwitch(
                value: settings.loudnessNormalizationEnabled.value,
                onChanged: settings.toggleLoudnessNormalization,
              ),
            )),
      if (!isDesktop)
        Obx(() => ListTile(
              title: Text("cacheSongs".tr),
              subtitle: Text("cacheSongsDes".tr),
              trailing: CustSwitch(
                value: settings.cacheSongs.value,
                onChanged: settings.toggleCachingSongsValue,
              ),
            )),
      if (!isDesktop)
        Obx(() => ListTile(
              title: Text("skipSilence".tr),
              subtitle: Text("skipSilenceDes".tr),
              trailing: CustSwitch(
                value: settings.skipSilenceEnabled.value,
                onChanged: settings.toggleSkipSilence,
              ),
            )),
      if (isDesktop)
        Obx(() => ListTile(
              title: Text("backgroundPlay".tr),
              subtitle: Text("backgroundPlayDes".tr),
              trailing: CustSwitch(
                value: settings.backgroundPlayEnabled.value,
                onChanged: settings.toggleBackgroundPlay,
              ),
            )),
      Obx(() => ListTile(
            title: Text("keepScreenOnWhilePlaying".tr),
            subtitle: Text("keepScreenOnWhilePlayingDes".tr),
            trailing: CustSwitch(
              value: settings.keepScreenAwake.value,
              onChanged: settings.toggleKeepScreenAwake,
            ),
          )),
      Obx(() => ListTile(
            title: Text("restoreLastPlaybackSession".tr),
            subtitle: Text("restoreLastPlaybackSessionDes".tr),
            trailing: CustSwitch(
              value: settings.restorePlaybackSession.value,
              onChanged: settings.toggleRestorePlaybackSession,
            ),
          )),
      Obx(() => ListTile(
            title: Text("autoOpenPlayer".tr),
            subtitle: Text("autoOpenPlayerDes".tr),
            trailing: CustSwitch(
              value: settings.autoOpenPlayer.value,
              onChanged: settings.toggleAutoOpenPlayer,
            ),
          )),
      if (!isDesktop)
        ListTile(
          title: Text("equalizer".tr),
          subtitle: Text("equalizerDes".tr),
          onTap: () async {
            try {
              await Get.find<PlayerController>().openEqualizer();
            } catch (e) {
              printERROR(e);
            }
          },
        ),
      if (!isDesktop)
        Obx(() => ListTile(
              title: Text("stopMusicOnTaskClear".tr),
              subtitle: Text("stopMusicOnTaskClearDes".tr),
              trailing: CustSwitch(
                value: settings.stopPlyabackOnSwipeAway.value,
                onChanged: settings.toggleStopPlyabackOnSwipeAway,
              ),
            )),
      if (GetPlatform.isAndroid)
        Obx(() => ListTile(
              title: Text("ignoreBatOpt".tr),
              onTap: settings.isIgnoringBatteryOptimizations.isFalse
                  ? settings.enableIgnoringBatteryOptimizations
                  : null,
              subtitle: Text(
                "${"status".tr}: ${settings.isIgnoringBatteryOptimizations.isTrue ? "enabled".tr : "disabled".tr}\n${"ignoreBatOptDes".tr}",
              ),
            )),
    ];
  }

  List<Widget> _buildServers(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
  ) {
    return [
      Obx(() {
        final servers = settings.servers;
        final activeId = settings.activeServerId.value;
        if (servers.isEmpty) {
          return ListTile(title: Text("noServersConfigured".tr));
        }
        return Column(
          children: [
            ...servers.map((server) => ListTile(
                  leading: Icon(_serverIcon(server.type)),
                  title: Text(server.name),
                  subtitle: Text(server.serverUrl?.isNotEmpty == true
                      ? server.serverUrl!
                      : _serverTypeLabelText(server.type).tr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<int>(
                        value: server.id,
                        groupValue: activeId,
                        onChanged: (v) {
                          if (v != null) settings.setActiveServer(v);
                        },
                      ),
                      if (!server.isDefault) ...[
                        if (server.type != ServerType.youtubeMusic)
                          IconButton(
                            icon: const Icon(Icons.wifi_find, size: 18),
                            tooltip: "testConnection".tr,
                            onPressed: () async {
                              final err =
                                  await settings.testServerConnection(server);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err == null
                                      ? "connectionSuccess".tr
                                      : "${"connectionFailed".tr}: $err"),
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
                          onPressed: () => settings.removeServer(server.id),
                        ),
                      ]
                    ],
                  ),
                )),
            Obx(() {
              final active = settings.activeServer;
              final isNonYouTube =
                  active != null && active.type != ServerType.youtubeMusic;
              if (!isNonYouTube) return const SizedBox.shrink();
              return ListTile(
                title: const Text("Resync Library Now"),
                trailing: TextButton(
                  onPressed: syncService.isSyncing.value
                      ? null
                      : () async {
                          await settings.resyncLibraryNow();
                        },
                  child:
                      Text(syncService.isSyncing.value ? "Syncing..." : "Sync"),
                ),
              );
            }),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAddProviderPicker(context),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                    title: Text(
                      "addServer".tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    ];
  }

  Future<void> _showAddProviderPicker(BuildContext context) async {
    final selected = await showDialog<ServerType>(
      context: context,
      builder: (_) => const _AddProviderDialog(),
    );
    if (selected == null || !context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AddServerDialog(serverType: selected),
    );
  }

  List<Widget> _buildDownload(
      BuildContext context, SettingsScreenController settings) {
    return [
      Obx(() => ListTile(
            title: Text("autoDownFavSong".tr),
            subtitle: Text("autoDownFavSongDes".tr),
            trailing: CustSwitch(
              value: settings.autoDownloadFavoriteSongEnabled.value,
              onChanged: settings.toggleAutoDownloadFavoriteSong,
            ),
          )),
      ListTile(
        title: Text("downloadingFormat".tr),
        subtitle: Text("downloadingFormatDes".tr),
        trailing: Obx(
          () => DropdownButton(
            underline: const SizedBox.shrink(),
            value: settings.downloadingFormat.value,
            items: const [
              DropdownMenuItem(value: "opus", child: Text("Opus/Ogg")),
              DropdownMenuItem(value: "m4a", child: Text("M4a")),
            ],
            onChanged: settings.changeDownloadingFormat,
          ),
        ),
      ),
      ListTile(
        title: Text("downloadLocation".tr),
        subtitle: Obx(() => Text(settings.isCurrentPathsupportDownDir
            ? "In App storage directory"
            : settings.downloadLocationPath.value)),
        trailing: TextButton(
          onPressed: settings.resetDownloadLocation,
          child: Text("reset".tr),
        ),
        onTap: settings.setDownloadLocation,
      ),
      if (GetPlatform.isAndroid)
        ListTile(
          title: Text("exportDowloadedFiles".tr),
          subtitle: Text("exportDowloadedFilesDes".tr),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const ExportFileDialog(),
          ).whenComplete(() => Get.delete<ExportFileDialogController>()),
        ),
      if (GetPlatform.isAndroid)
        ListTile(
          title: Text("exportedFileLocation".tr),
          subtitle: Obx(() => Text(settings.exportLocationPath.value)),
          onTap: settings.setExportedLocation,
        ),
    ];
  }

  List<Widget> _buildBackup(BuildContext context) {
    return [
      ListTile(
        title: Text("backupAppData".tr),
        subtitle: Text("backupSettingsAndPlaylistsDes".tr),
        onTap: () => showDialog(
          context: context,
          builder: (_) => const BackupDialog(),
        ).whenComplete(() => Get.delete<BackupDialogController>()),
      ),
      ListTile(
        title: Text("restoreAppData".tr),
        subtitle: Text("restoreSettingsAndPlaylistsDes".tr),
        onTap: () => showDialog(
          context: context,
          builder: (_) => const RestoreDialog(),
        ).whenComplete(() => Get.delete<RestoreDialogController>()),
      ),
    ];
  }

  List<Widget> _buildMisc(
      BuildContext context, SettingsScreenController settings) {
    return [
      ListTile(
        title: Text("resetToDefault".tr),
        subtitle: Text("resetToDefaultDes".tr),
        onTap: () async {
          await settings.resetAppSettingsToDefault();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, "resetToDefaultMsg".tr, size: SnackBarSize.BIG),
          );
        },
      ),
    ];
  }

  List<Widget> _buildInfo(
      BuildContext context, SettingsScreenController settings) {
    return [
      Obx(() => ListTile(
            leading: const Icon(Icons.system_update_alt, size: 20),
            title: Text("checkForUpdatesOnStartup".tr),
            trailing: CustSwitch(
              value: settings.checkForUpdatesOnStartup.value,
              onChanged: settings.toggleCheckForUpdatesOnStartup,
            ),
          )),
      ListTile(
        leading: const Icon(Icons.system_update, size: 20),
        title: Text("checkForUpdates".tr),
        onTap: () async {
          final upToDate = "upToDate".tr;
          final checking = "checkingForUpdates".tr;
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
      ListTile(
        leading: const Icon(Icons.language, size: 20),
        title: Text("openOpenlystWebsite".tr),
        onTap: () => launchUrl(
          Uri.parse('https://openlyst.ink/'),
          mode: LaunchMode.externalApplication,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.code, size: 20),
        title: Text("openGitlab".tr),
        subtitle: Text("gitlabDes".tr),
        onTap: () => launchUrl(
          Uri.parse('https://gitlab.com/Openlyst/doudou/'),
          mode: LaunchMode.externalApplication,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              "Doudou",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(settings.currentVersion),
          ],
        ),
      ),
    ];
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF252525)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon,
                    size: 18, color: Colors.white.withValues(alpha: 0.82)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Theme(
            data: Theme.of(context).copyWith(
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.white70,
                textColor: Colors.white,
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  const _SettingsSubPage({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        elevation: 0,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _SettingsCard(
                icon: icon,
                title: title,
                children: children,
              ),
            ],
          ),
        ),
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

class _AddProviderDialog extends StatelessWidget {
  const _AddProviderDialog();

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                children: [
                  Text(
                    "addServer".tr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < ServerType.values.length; i++) ...[
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(_serverIcon(ServerType.values[i])),
                title: Text(_serverTypeLabelText(ServerType.values[i]).tr),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => Navigator.of(context).pop(ServerType.values[i]),
              ),
              if (i < ServerType.values.length - 1)
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("cancel".tr),
              ),
            ),
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
  const icons = <ServerType, IconData>{
    ServerType.youtubeMusic: Icons.play_circle_outline,
    ServerType.subsonic: Icons.waves,
    ServerType.jellyfin: Icons.tv,
    ServerType.plex: Icons.cloud,
  };
  return icons[type] ?? Icons.storage_outlined;
}

String _serverTypeLabelText(ServerType type) {
  const labels = <ServerType, String>{
    ServerType.youtubeMusic: "youtubeMusic",
    ServerType.subsonic: "subsonic",
    ServerType.jellyfin: "jellyfin",
    ServerType.plex: "plex",
  };
  return labels[type] ?? type.name;
}
