import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '/utils/app_l10n.dart';
import '/utils/helper.dart';
import '/models/server.dart';
import '/services/discord_rpc_service.dart';
import '/services/library_sync_service.dart';
import '/services/music_service.dart';
import '/services/tv_service.dart';
import '/ui/constants/layout.dart';
import '/ui/design/doudou_colors.dart';
import '/ui/design/doudou_layout.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Library/library_controller.dart';
import '/ui/screens/Settings/add_server_dialog.dart';
import '/ui/screens/Settings/settings_dialogs.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/ui/widgets/backup_dialog.dart';
import '/ui/widgets/cust_switch.dart';
import '/ui/widgets/export_file_dialog.dart';
import '/ui/widgets/link_piped.dart';
import '/ui/widgets/new_version_dialog.dart';
import '/ui/widgets/restore_dialog.dart';
import '/ui/widgets/snackbar.dart';
import '/ui/widgets/tv_focus_highlight.dart';

class SettingsScreen extends GetView<SettingsScreenController> {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    return _SettingsView(isBottomNavActive: isBottomNavActive);
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

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.isBottomNavActive});
  final bool isBottomNavActive;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  _SettingsSectionId _selected = _SettingsSectionId.personalisation;

  static const _sectionMeta = <(_SettingsSectionId, IconData, String)>[
    (
      _SettingsSectionId.personalisation,
      Icons.palette_outlined,
      'personalisation'
    ),
    (_SettingsSectionId.content, Icons.movie_outlined, 'content'),
    (_SettingsSectionId.playback, Icons.music_note_outlined, 'musicPlayback'),
    (_SettingsSectionId.servers, Icons.dns_outlined, 'servers'),
    (_SettingsSectionId.download, Icons.download_outlined, 'download'),
    (_SettingsSectionId.backup, Icons.restore_outlined, 'backup'),
    (_SettingsSectionId.misc, Icons.miscellaneous_services_outlined, 'misc'),
    (_SettingsSectionId.info, Icons.info_outline, 'appInfo'),
  ];

  static const _mobileClusters = <(_SettingsSectionId, String, String)>[
    (_SettingsSectionId.servers, 'ACCOUNTS', 'accounts'),
    (_SettingsSectionId.backup, 'ACCOUNTS', 'accounts'),
    (_SettingsSectionId.content, 'USER', 'user'),
    (_SettingsSectionId.playback, 'USER', 'user'),
    (_SettingsSectionId.misc, 'USER', 'user'),
    (_SettingsSectionId.personalisation, 'APPEARANCE', 'appearance'),
    (_SettingsSectionId.download, 'APPEARANCE', 'appearance'),
    (_SettingsSectionId.info, 'APPEARANCE', 'appearance'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsScreenController>();
    final sync = Get.find<LibrarySyncService>();
    final layout = DoudouLayout.of(context);
    final useTwoPane =
        layout.isDesktop || (layout.isTablet && layout.size.width >= 840);
    final mq = MediaQuery.of(context);

    final topPadding = mq.padding.top +
        (layout.isPhone ? kTopPaddingNarrow : kTopPaddingDesktop);
    final horizontalPadding = widget.isBottomNavActive
        ? kContentLeftPaddingWithBottomNav
        : (useTwoPane ? 0.0 : layout.contentPadding.left);
    final rightPadding = widget.isBottomNavActive
        ? kContentRightPaddingSettingsWithBottomNav
        : layout.contentPadding.right;
    final bottomPadding = widget.isBottomNavActive
        ? kSettingsListBottomPadding
        : kContentBottomPaddingWithPlayer;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        rightPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, useTwoPane),
          Expanded(
            child: useTwoPane
                ? _buildTwoPane(context, settings, sync)
                : _buildSinglePane(context, settings, sync, bottomPadding),
          ),
        ],
      ),
    );

    if (useTwoPane) return content;
    return content;
  }

  Widget _buildHeader(BuildContext context, bool useTwoPane) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DoudouSpace.s4,
        10,
        DoudouSpace.s8,
        DoudouSpace.s16,
      ),
      child: Row(
        children: [
          if (useTwoPane) ...[
            Icon(
              Icons.settings_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: DoudouSpace.s8),
          ],
          Expanded(
            child: Text(
              context.l10n.settings,
              style: (useTwoPane
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPane(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: _buildSectionNav(context),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: Duration(
              milliseconds: (220 * settings.animationSpeedFactor).round(),
            ),
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: _SettingsCard(
                        icon: _sectionIcon(_selected),
                        title: _sectionTitle(context, _selected),
                        borderRadius: BorderRadius.zero,
                        margin: EdgeInsets.zero,
                        children: _buildSectionChildren(
                          context,
                          settings,
                          sync,
                          _selected,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePane(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    double bottomPadding,
  ) {
    final grouped = <String, List<_SettingsSectionId>>{};
    for (final cluster in _mobileClusters) {
      grouped.putIfAbsent(cluster.$2, () => []).add(cluster.$1);
    }

    final entries = grouped.entries.toList();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final header = entries[index].key;
        final sections = entries[index].value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                DoudouSpace.s8,
                index == 0 ? DoudouSpace.s2 : DoudouSpace.s20,
                DoudouSpace.s8,
                DoudouSpace.s8,
              ),
              child: Text(
                header,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.doudouColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
            _SettingsCard(
              children: [
                for (int i = 0; i < sections.length; i++) ...[
                  _buildMobileSectionRow(
                    context,
                    settings,
                    sync,
                    sections[i],
                  ),
                  if (i < sections.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionNav(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;
    final grouped = <String, List<_SettingsSectionId>>{};
    for (final cluster in _mobileClusters) {
      grouped.putIfAbsent(cluster.$2, () => []).add(cluster.$1);
    }

    return Card(
      color: theme.cardColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(DoudouSpace.s12),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DoudouSpace.s4,
                DoudouSpace.s8,
                DoudouSpace.s4,
                DoudouSpace.s8,
              ),
              child: Text(
                entry.key,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final id in entry.value) _buildNavTile(context, id),
          ],
        ],
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, _SettingsSectionId id) {
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    final selected = _selected == id;
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    final tile = ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onTap: () => setState(() => _selected = id),
      leading: Icon(
        meta.$2,
        size: 18,
        color: selected ? colors.textPrimary : colors.textSecondary,
      ),
      title: Text(
        _sectionTitle(context, id),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: selected ? colors.textTertiary : colors.textDisabled,
      ),
      selected: selected,
      selectedTileColor: colors.surfaceSelected,
    );

    if (_isTv(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TvFocusHighlight(
          borderRadius: 10,
          onSelect: () => setState(() => _selected = id),
          child: tile,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: tile,
    );
  }

  Widget _buildMobileSectionRow(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    _SettingsSectionId id,
  ) {
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    final tile = ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          meta.$2,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
      title: Text(
        _sectionTitle(context, id),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        _sectionSubtitle(context, id),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.textDisabled,
      ),
      onTap: () => _openSectionSubPage(context, settings, sync, id),
    );

    if (_isTv(context)) {
      return TvFocusHighlight(
        borderRadius: 10,
        onSelect: () => _openSectionSubPage(context, settings, sync, id),
        child: tile,
      );
    }
    return tile;
  }

  void _openSectionSubPage(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    _SettingsSectionId id,
  ) {
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsSubPage(
          icon: meta.$2,
          title: _sectionTitle(context, id),
          children: _buildSectionChildren(context, settings, sync, id),
        ),
      ),
    );
  }

  IconData _sectionIcon(_SettingsSectionId id) {
    return _sectionMeta.firstWhere((e) => e.$1 == id).$2;
  }

  String _sectionTitle(BuildContext context, _SettingsSectionId id) {
    final l10n = context.l10n;
    final key = _sectionMeta.firstWhere((e) => e.$1 == id).$3;
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

  List<Widget> _buildPersonalisation(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final isDesktop = GetPlatform.isDesktop;

    return [
      _SettingsListTile(
        title: context.l10n.themeMode,
        subtitle:
            Obx(() => Text(_themeModeLabel(settings.themeModetype.value))),
        onTap: () => showDialog(
          context: context,
          builder: (_) => const ThemeSelectorDialog(),
        ),
      ),
      _SettingsListTile(
        title: context.l10n.lyricsDynamicColor,
        subtitle: context.l10n.lyricsDynamicColorDes,
        trailing: Obx(() => CustSwitch(
              value: settings.lyricsDynamicColorEnabled.value,
              onChanged: settings.setLyricsDynamicColorEnabled,
            )),
        onTap: () => settings.setLyricsDynamicColorEnabled(
          !settings.lyricsDynamicColorEnabled.value,
        ),
      ),
      _SettingsListTile(
        title: context.l10n.syncedLyricsHighlightStyle,
        subtitle: context.l10n.syncedLyricsHighlightStyleDes,
        trailing: Obx(() => _SettingsDropdown<SyncedLyricsHighlightStyle>(
              value: settings.syncedLyricsHighlightStyle.value,
              items: [
                (
                  SyncedLyricsHighlightStyle.block,
                  context.l10n.lyricsHighlightBlock
                ),
                (
                  SyncedLyricsHighlightStyle.karaoke,
                  context.l10n.lyricsHighlightKaraoke
                ),
              ],
              onChanged: settings.setSyncedLyricsHighlightStyle,
            )),
      ),
      _SettingsListTile(
        title: context.l10n.language,
        subtitle: context.l10n.languageDes,
        trailing: Obx(() => _SettingsDropdown<String>(
              value: settings.currentAppLanguageCode.value,
              items: supportedLocalesDisplay.entries
                  .map((e) => (e.key, e.value))
                  .toList(),
              onChanged: settings.setAppLanguage,
            )),
      ),
      if (!isDesktop)
        _SettingsListTile(
          title: context.l10n.playerUi,
          subtitle: context.l10n.playerUiDes,
          trailing: Obx(() => _SettingsDropdown<int>(
                value: settings.playerUi.value,
                items: [
                  (0, context.l10n.standard),
                  (1, context.l10n.gesture),
                ],
                onChanged: settings.setPlayerUi,
              )),
        ),
      _SettingsListTile(
        title: context.l10n.animationSpeed,
        subtitle: context.l10n.animationSpeedDes,
        trailing: Obx(() => _SettingsDropdown<AnimationSpeed>(
              value: settings.animationSpeed.value,
              items: [
                (AnimationSpeed.off, context.l10n.animationSpeedOff),
                (AnimationSpeed.fast, context.l10n.animationSpeedFast),
                (AnimationSpeed.normal, context.l10n.animationSpeedNormal),
                (AnimationSpeed.slow, context.l10n.animationSpeedSlow),
              ],
              onChanged: settings.setAnimationSpeed,
            )),
      ),
      _SettingsListTile(
        title: context.l10n.enableSlidableAction,
        subtitle: context.l10n.enableSlidableActionDes,
        trailing: Obx(() => CustSwitch(
              value: settings.slidableActionEnabled.value,
              onChanged: settings.toggleSlidableAction,
            )),
        onTap: () => settings.toggleSlidableAction(
          !settings.slidableActionEnabled.value,
        ),
      ),
    ];
  }

  String _themeModeLabel(ThemeType type) {
    final l10n = Get.context?.l10n;
    if (l10n == null) return '';
    return switch (type) {
      ThemeType.dynamic => l10n.dynamicTheme,
      ThemeType.system => l10n.systemDefault,
      ThemeType.dark => l10n.dark,
      ThemeType.oled => l10n.oled,
      ThemeType.light => l10n.light,
    };
  }

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
          subtitle: Obx(() =>
              Text(_discoverContentLabel(settings.discoverContentType.value))),
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

  String _discoverContentLabel(String value) {
    final l10n = Get.context?.l10n;
    if (l10n == null) return value;
    return switch (value) {
      'QP' => l10n.quickpicks,
      'TMV' => l10n.topmusicvideos,
      'TR' => l10n.trending,
      'BOLI' => l10n.basedOnLast,
      _ => value,
    };
  }

  List<Widget> _buildPlayback(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final isDesktop = GetPlatform.isDesktop;

    return [
      _SettingsListTile(
        title: context.l10n.streamingQuality,
        subtitle: context.l10n.streamingQualityDes,
        trailing: Obx(() => _SettingsDropdown<AudioQuality>(
              value: settings.streamingQuality.value,
              items: [
                (AudioQuality.Low, context.l10n.low),
                (AudioQuality.High, context.l10n.high),
              ],
              onChanged: settings.setStreamingQuality,
            )),
      ),
      if (GetPlatform.isAndroid)
        _SettingsListTile(
          title: context.l10n.loudnessNormalization,
          subtitle: context.l10n.loudnessNormalizationDes,
          trailing: Obx(() => CustSwitch(
                value: settings.loudnessNormalizationEnabled.value,
                onChanged: settings.toggleLoudnessNormalization,
              )),
          onTap: () => settings.toggleLoudnessNormalization(
            !settings.loudnessNormalizationEnabled.value,
          ),
        ),
      if (!isDesktop)
        _SettingsListTile(
          title: context.l10n.cacheSongs,
          subtitle: context.l10n.cacheSongsDes,
          trailing: Obx(() => CustSwitch(
                value: settings.cacheSongs.value,
                onChanged: settings.toggleCachingSongsValue,
              )),
          onTap: () => settings.toggleCachingSongsValue(
            !settings.cacheSongs.value,
          ),
        ),
      if (!isDesktop)
        _SettingsListTile(
          title: context.l10n.skipSilence,
          subtitle: context.l10n.skipSilenceDes,
          trailing: Obx(() => CustSwitch(
                value: settings.skipSilenceEnabled.value,
                onChanged: settings.toggleSkipSilence,
              )),
          onTap: () => settings.toggleSkipSilence(
            !settings.skipSilenceEnabled.value,
          ),
        ),
      if (isDesktop)
        _SettingsListTile(
          title: context.l10n.backgroundPlay,
          subtitle: context.l10n.backgroundPlayDes,
          trailing: Obx(() => CustSwitch(
                value: settings.backgroundPlayEnabled.value,
                onChanged: settings.toggleBackgroundPlay,
              )),
          onTap: () => settings.toggleBackgroundPlay(
            !settings.backgroundPlayEnabled.value,
          ),
        ),
      _SettingsListTile(
        title: context.l10n.keepScreenOnWhilePlaying,
        subtitle: context.l10n.keepScreenOnWhilePlayingDes,
        trailing: Obx(() => CustSwitch(
              value: settings.keepScreenAwake.value,
              onChanged: settings.toggleKeepScreenAwake,
            )),
        onTap: () => settings.toggleKeepScreenAwake(
          !settings.keepScreenAwake.value,
        ),
      ),
      _SettingsListTile(
        title: context.l10n.autoRadio,
        subtitle: context.l10n.autoRadioDes,
        trailing: Obx(() => CustSwitch(
              value: settings.autoRadioEnabled.value,
              onChanged: settings.toggleAutoRadio,
            )),
        onTap: () => settings.toggleAutoRadio(!settings.autoRadioEnabled.value),
      ),
      _SettingsListTile(
        title: context.l10n.restoreLastPlaybackSession,
        subtitle: context.l10n.restoreLastPlaybackSessionDes,
        trailing: Obx(() => CustSwitch(
              value: settings.restorePlaybackSession.value,
              onChanged: settings.toggleRestorePlaybackSession,
            )),
        onTap: () => settings.toggleRestorePlaybackSession(
          !settings.restorePlaybackSession.value,
        ),
      ),
      _SettingsListTile(
        title: context.l10n.autoOpenPlayer,
        subtitle: context.l10n.autoOpenPlayerDes,
        trailing: Obx(() => CustSwitch(
              value: settings.autoOpenPlayer.value,
              onChanged: settings.toggleAutoOpenPlayer,
            )),
        onTap: () => settings.toggleAutoOpenPlayer(
          !settings.autoOpenPlayer.value,
        ),
      ),
      if (!isDesktop)
        _SettingsListTile(
          title: context.l10n.equalizer,
          subtitle: context.l10n.equalizerDes,
          onTap: () async {
            try {
              await Get.find<PlayerController>().openEqualizer();
            } catch (e) {
              printERROR(e);
            }
          },
        ),
      if (!isDesktop)
        _SettingsListTile(
          title: context.l10n.stopMusicOnTaskClear,
          subtitle: context.l10n.stopMusicOnTaskClearDes,
          trailing: Obx(() => CustSwitch(
                value: settings.stopPlyabackOnSwipeAway.value,
                onChanged: settings.toggleStopPlyabackOnSwipeAway,
              )),
          onTap: () => settings.toggleStopPlyabackOnSwipeAway(
            !settings.stopPlyabackOnSwipeAway.value,
          ),
        ),
      if (GetPlatform.isAndroid)
        _SettingsListTile(
          title: context.l10n.ignoreBatOpt,
          subtitle: Obx(() => _batteryStatusText(context, settings)),
          onTap: () {
            if (settings.isIgnoringBatteryOptimizations.isFalse) {
              settings.enableIgnoringBatteryOptimizations();
            }
          },
        ),
    ];
  }

  Widget _batteryStatusText(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final l10n = context.l10n;
    final colors = context.doudouColors;
    final theme = Theme.of(context);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
        ),
        children: [
          TextSpan(text: '${l10n.status}: '),
          TextSpan(
            text: settings.isIgnoringBatteryOptimizations.isTrue
                ? l10n.enabled
                : l10n.disabled,
            style: TextStyle(
              color: settings.isIgnoringBatteryOptimizations.isTrue
                  ? colors.success
                  : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '\n${l10n.ignoreBatOptDes}'),
        ],
      ),
    );
  }

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
            child: Text(sync.isSyncing.value ? 'Syncing...' : 'Sync'),
          ),
        );
      }),
    ];
  }

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
        _SettingsListTile(
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
          onTap: () => _testDiscordRpc(context, settings),
        ),
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
    );
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

class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final dynamic leading;
  final String title;
  final dynamic subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    Widget? titleWidget;
    if (leading is Widget) {
      titleWidget = leading as Widget;
    }

    Widget? subtitleWidget;
    if (subtitle is Widget) {
      subtitleWidget = subtitle as Widget;
    } else if (subtitle is String) {
      subtitleWidget = Text(
        subtitle as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
        ),
      );
    } else if (subtitle is TextSpan) {
      subtitleWidget = RichText(
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        text: subtitle as TextSpan,
      );
    }

    Widget tile = ListTile(
      enabled: enabled,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DoudouSpace.s12,
        vertical: DoudouSpace.s2,
      ),
      leading: titleWidget,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitleWidget,
      trailing: trailing,
      onTap: onTap,
    );

    if (onTap != null && _isTv(context)) {
      tile = TvFocusHighlight(
        borderRadius: 10,
        onSelect: onTap,
        child: tile,
      );
    }

    return tile;
  }

  bool _isTv(BuildContext context) {
    if (!Get.isRegistered<TvService>()) return false;
    return Get.find<TvService>().isTV.value;
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButton<T>(
      isDense: true,
      value: value,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      style: theme.textTheme.bodyMedium,
      dropdownColor: theme.cardColor,
      borderRadius: DoudouRadii.r12,
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e.$1,
                child: Text(e.$2),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    this.icon,
    this.title,
    this.borderRadius = DoudouRadii.r16,
    this.margin = const EdgeInsets.symmetric(horizontal: DoudouSpace.s4),
    required this.children,
  });

  final IconData? icon;
  final String? title;
  final BorderRadius borderRadius;
  final EdgeInsets margin;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    return Card(
      color: theme.cardColor,
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DoudouSpace.s16,
                DoudouSpace.s16,
                DoudouSpace.s16,
                DoudouSpace.s8,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: colors.textSecondary),
                    const SizedBox(width: DoudouSpace.s8),
                  ],
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (title != null) const Divider(height: 1),
          ...children,
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DoudouSpace.s16),
          child: _SettingsCard(
            icon: icon,
            title: title,
            children: children,
          ),
        ),
      ),
    );
  }
}
