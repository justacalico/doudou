import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doudou/utils/helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common_dialog_widget.dart';
import '../../widgets/cust_switch.dart';
import '../../widgets/tv_focus_highlight.dart';
import '/services/tv_service.dart';
import '/services/discord_rpc_service.dart';
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
import '/models/server.dart';
import 'settings_screen_controller.dart';
import '/app/theme/app_theme_provider.dart';

const bool kIsPlayStore = bool.fromEnvironment('PLAYSTORE', defaultValue: false);
bool _ytmProviderUnlocked = false;

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
    (_SettingsSectionId.playback, Icons.music_note_outlined, "musicPlayback"),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final topPadding = statusBarHeight +
        (context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault);
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

    return Padding(
      padding: outerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(useTwoPane ? 0 : 8, 10, 8, 12),
            child: Row(
              children: [
                if (useTwoPane)
                  Icon(
                    Icons.settings_outlined,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.75),
                    size: 18,
                  ),
                if (useTwoPane) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.settings,
                    textAlign: TextAlign.left,
                    style: (useTwoPane
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
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
                        width: 300,
                        child: _buildSectionNav(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_selected),
                                child: _buildSingleSection(
                                    context, settings, syncService, _selected),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : _buildMobileSectionList(context, settings, syncService),
          ),
          if (useTwoPane)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 12),
              child: Text(
                settings.currentVersion,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionNav(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: ListView(
        children: [
          for (final cluster in _mobileClusters) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
              child: Text(
                cluster.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
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
                      ? colorScheme.onSurface.withValues(alpha: 0.10)
                      : theme.cardColor.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.50)
                        : theme.dividerColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    dense: true,
                    onTap: () => setState(() => _selected = sectionId),
                    leading: Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                    title: Text(
                      _sectionTitle(context, titleKey),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: selected
                          ? colorScheme.onSurface.withValues(alpha: 0.4)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
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
    final bottomPadding = widget.isBottomNavActive
        ? kSettingsListBottomPadding
        : kContentBottomPaddingWithPlayer;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
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
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.25)),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
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
                          color: theme.dividerColor.withValues(alpha: 0.35),
                        ),
                    ],
                  ],
                ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final meta = _sectionMeta.firstWhere((e) => e.$1 == id);
    final badge = _sectionBadge(id);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          meta.$2,
          size: 18,
          color: colorScheme.onSurface.withValues(alpha: 0.82),
        ),
      ),
      title: Text(
        _sectionTitle(context, meta.$3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        _sectionSubtitle(id),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
      trailing: badge == null
          ? Icon(Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.6))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
      onTap: () => _openSectionSubPage(context, settings, syncService, id),
    );
  }

  String _sectionTitle(BuildContext context, String key) {
    final l10n = context.l10n;
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

  String _sectionSubtitle(_SettingsSectionId id) {
    return switch (id) {
      _SettingsSectionId.servers => context.l10n.servers,
      _SettingsSectionId.backup => context.l10n.backupSettingsAndPlaylistsDes,
      _SettingsSectionId.content => context.l10n.content,
      _SettingsSectionId.playback => context.l10n.musicPlayback,
      _SettingsSectionId.misc => context.l10n.misc,
      _SettingsSectionId.personalisation => context.l10n.themeMode,
      _SettingsSectionId.download => context.l10n.download,
      _SettingsSectionId.info => context.l10n.appInfo,
    };
  }

  String? _sectionBadge(_SettingsSectionId id) {
    return switch (id) {
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
          title: _sectionTitle(context, meta.$3),
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
      title: _sectionTitle(context, meta.$3),
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
    final theme = Theme.of(context);
    return [
      ListTile(
        title: Text(context.l10n.themeMode),
        trailing: Consumer(
          builder: (context, ref, _) {
            return Obx(
              () => SizedBox(
                width: 140,
                child: DropdownButton<ThemeType>(
                  isDense: true,
                  value: settings.themeModetype.value,
                  underline: const SizedBox.shrink(),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  style: theme.textTheme.bodyMedium,
                  dropdownColor: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    DropdownMenuItem(
                      value: ThemeType.dynamic,
                      child: Text(context.l10n.dynamicTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeType.system,
                      child: Text(context.l10n.systemDefault),
                    ),
                    DropdownMenuItem(
                      value: ThemeType.dark,
                      child: Text(context.l10n.dark),
                    ),
                    DropdownMenuItem(
                      value: ThemeType.oled,
                      child: Text(context.l10n.oled),
                    ),
                    DropdownMenuItem(
                      value: ThemeType.light,
                      child: Text(context.l10n.light),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      settings.onThemeChange(v);
                      ref.read(appThemeProvider.notifier).setThemeType(v);
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
      Obx(() => ListTile(
            title: Text(context.l10n.lyricsDynamicColor),
            subtitle: Text(context.l10n.lyricsDynamicColorDes),
            trailing: CustSwitch(
              value: settings.lyricsDynamicColorEnabled.value,
              onChanged: settings.setLyricsDynamicColorEnabled,
            ),
          )),
      ListTile(
        title: Text(context.l10n.syncedLyricsHighlightStyle),
        subtitle: Text(context.l10n.syncedLyricsHighlightStyleDes),
        trailing: Obx(
          () => DropdownButton<SyncedLyricsHighlightStyle>(
            value: settings.syncedLyricsHighlightStyle.value,
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem(
                value: SyncedLyricsHighlightStyle.block,
                child: Text(context.l10n.lyricsHighlightBlock),
              ),
              DropdownMenuItem(
                value: SyncedLyricsHighlightStyle.karaoke,
                child: Text(context.l10n.lyricsHighlightKaraoke),
              ),
            ],
            onChanged: (v) {
              if (v != null) settings.setSyncedLyricsHighlightStyle(v);
            },
          ),
        ),
      ),
      ListTile(
        title: Text(context.l10n.language),
        subtitle: Text(context.l10n.languageDes),
        trailing: Obx(
          () => DropdownButton(
            menuMaxHeight: Get.height - 250,
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            value: settings.currentAppLanguageCode.value,
            items: supportedLocalesDisplay.entries
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
          title: Text(context.l10n.playerUi),
          subtitle: Text(context.l10n.playerUiDes),
          trailing: Obx(
            () => DropdownButton(
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: theme.textTheme.bodyMedium,
              dropdownColor: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              value: settings.playerUi.value,
              items: [
                DropdownMenuItem(value: 0, child: Text(context.l10n.standard)),
                DropdownMenuItem(value: 1, child: Text(context.l10n.gesture)),
              ],
              onChanged: settings.setPlayerUi,
            ),
          ),
        ),
      ListTile(
        title: Text(context.l10n.animationSpeed),
        subtitle: Text(context.l10n.animationSpeedDes),
        trailing: Obx(
          () => DropdownButton<AnimationSpeed>(
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            value: settings.animationSpeed.value,
            items: [
              DropdownMenuItem(
                  value: AnimationSpeed.off,
                  child: Text(context.l10n.animationSpeedOff)),
              DropdownMenuItem(
                  value: AnimationSpeed.fast,
                  child: Text(context.l10n.animationSpeedFast)),
              DropdownMenuItem(
                  value: AnimationSpeed.normal,
                  child: Text(context.l10n.animationSpeedNormal)),
              DropdownMenuItem(
                  value: AnimationSpeed.slow,
                  child: Text(context.l10n.animationSpeedSlow)),
            ],
            onChanged: (v) {
              if (v != null) settings.setAnimationSpeed(v);
            },
          ),
        ),
      ),
      Obx(() => ListTile(
            title: Text(context.l10n.enableSlidableAction),
            subtitle: Text(context.l10n.enableSlidableActionDes),
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
    final theme = Theme.of(context);
    return [
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return ListTile(
          title: Text(context.l10n.setDiscoverContent),
          subtitle: Text(
            settings.discoverContentType.value == "QP"
                ? context.l10n.quickpicks
                : settings.discoverContentType.value == "TMV"
                    ? context.l10n.topmusicvideos
                    : settings.discoverContentType.value == "TR"
                        ? context.l10n.trending
                        : context.l10n.basedOnLast,
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
          title: Text(context.l10n.homeContentCount),
          subtitle: Text(context.l10n.homeContentCountDes),
          trailing: DropdownButton(
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
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
          title: Text(context.l10n.sidebarMode),
          subtitle: Text(context.l10n.sidebarModeDes),
          trailing: Obx(
            () => DropdownButton<SidebarMode>(
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: theme.textTheme.bodyMedium,
              dropdownColor: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              value: settings.sidebarMode.value,
              items: [
                DropdownMenuItem(
                    value: SidebarMode.auto,
                    child: Text(context.l10n.sidebarModeAuto)),
                DropdownMenuItem(
                    value: SidebarMode.collapsed,
                    child: Text(context.l10n.sidebarModeCollapsed)),
                DropdownMenuItem(
                    value: SidebarMode.expanded,
                    child: Text(context.l10n.sidebarModeExpanded)),
              ],
              onChanged: settings.setSidebarMode,
            ),
          ),
        ),
      Obx(() => ListTile(
            title: Text(context.l10n.cacheHomeScreenData),
            subtitle: Text(context.l10n.cacheHomeScreenDataDes),
            trailing: CustSwitch(
              value: settings.cacheHomeScreenData.value,
              onChanged: settings.toggleCacheHomeScreenData,
            ),
          )),
      Obx(() {
        final isYt = settings.activeServer?.type == ServerType.youtubeMusic;
        if (!isYt) return const SizedBox.shrink();
        return ListTile(
          title: Text(context.l10n.piped),
          subtitle: Text(context.l10n.linkPipedDes),
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
        return ListTile(
          title: Text(context.l10n.resetblacklistedplaylist),
          subtitle: Text(context.l10n.resetblacklistedplaylistDes),
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
      ListTile(
        title: Text(context.l10n.clearImgCache),
        subtitle: Text(context.l10n.clearImgCacheDes),
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

  List<Widget> _buildPlayback(
      BuildContext context, SettingsScreenController settings) {
    final isDesktop = GetPlatform.isDesktop;
    final theme = Theme.of(context);
    return [
      ListTile(
        title: Text(context.l10n.streamingQuality),
        subtitle: Text(context.l10n.streamingQualityDes),
        trailing: Obx(
          () => DropdownButton(
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            value: settings.streamingQuality.value,
            items: [
              DropdownMenuItem(
                  value: AudioQuality.Low, child: Text(context.l10n.low)),
              DropdownMenuItem(
                  value: AudioQuality.High, child: Text(context.l10n.high)),
            ],
            onChanged: settings.setStreamingQuality,
          ),
        ),
      ),
      if (GetPlatform.isAndroid)
        Obx(() => ListTile(
              title: Text(context.l10n.loudnessNormalization),
              subtitle: Text(context.l10n.loudnessNormalizationDes),
              trailing: CustSwitch(
                value: settings.loudnessNormalizationEnabled.value,
                onChanged: settings.toggleLoudnessNormalization,
              ),
            )),
      if (!isDesktop)
        Obx(() => ListTile(
              title: Text(context.l10n.cacheSongs),
              subtitle: Text(context.l10n.cacheSongsDes),
              trailing: CustSwitch(
                value: settings.cacheSongs.value,
                onChanged: settings.toggleCachingSongsValue,
              ),
            )),
      if (!isDesktop)
        Obx(() => ListTile(
              title: Text(context.l10n.skipSilence),
              subtitle: Text(context.l10n.skipSilenceDes),
              trailing: CustSwitch(
                value: settings.skipSilenceEnabled.value,
                onChanged: settings.toggleSkipSilence,
              ),
            )),
      if (isDesktop)
        Obx(() => ListTile(
              title: Text(context.l10n.backgroundPlay),
              subtitle: Text(context.l10n.backgroundPlayDes),
              trailing: CustSwitch(
                value: settings.backgroundPlayEnabled.value,
                onChanged: settings.toggleBackgroundPlay,
              ),
            )),
      Obx(() => ListTile(
            title: Text(context.l10n.keepScreenOnWhilePlaying),
            subtitle: Text(context.l10n.keepScreenOnWhilePlayingDes),
            trailing: CustSwitch(
              value: settings.keepScreenAwake.value,
              onChanged: settings.toggleKeepScreenAwake,
            ),
          )),
      Obx(() => ListTile(
            title: Text(context.l10n.autoRadio),
            subtitle: Text(context.l10n.autoRadioDes),
            trailing: CustSwitch(
              value: settings.autoRadioEnabled.value,
              onChanged: settings.toggleAutoRadio,
            ),
          )),
      Obx(() => ListTile(
            title: Text(context.l10n.restoreLastPlaybackSession),
            subtitle: Text(context.l10n.restoreLastPlaybackSessionDes),
            trailing: CustSwitch(
              value: settings.restorePlaybackSession.value,
              onChanged: settings.toggleRestorePlaybackSession,
            ),
          )),
      Obx(() => ListTile(
            title: Text(context.l10n.autoOpenPlayer),
            subtitle: Text(context.l10n.autoOpenPlayerDes),
            trailing: CustSwitch(
              value: settings.autoOpenPlayer.value,
              onChanged: settings.toggleAutoOpenPlayer,
            ),
          )),
      if (!isDesktop)
        ListTile(
          title: Text(context.l10n.equalizer),
          subtitle: Text(context.l10n.equalizerDes),
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
              title: Text(context.l10n.stopMusicOnTaskClear),
              subtitle: Text(context.l10n.stopMusicOnTaskClearDes),
              trailing: CustSwitch(
                value: settings.stopPlyabackOnSwipeAway.value,
                onChanged: settings.toggleStopPlyabackOnSwipeAway,
              ),
            )),
      if (GetPlatform.isAndroid)
        Obx(() => ListTile(
              title: Text(context.l10n.ignoreBatOpt),
              onTap: settings.isIgnoringBatteryOptimizations.isFalse
                  ? settings.enableIgnoringBatteryOptimizations
                  : null,
              subtitle: Text(
                "${context.l10n.status}: ${settings.isIgnoringBatteryOptimizations.isTrue ? context.l10n.enabled : context.l10n.disabled}\n${context.l10n.ignoreBatOptDes}",
              ),
            )),
    ];
  }

  List<Widget> _buildServers(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService syncService,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return [
      Obx(() {
        final servers = settings.servers;
        final activeId = settings.activeServerId.value;
        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAddProviderPicker(context),
                child: Ink(
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.28),
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
                        color: colorScheme.onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add,
                          size: 16, color: colorScheme.onSurface),
                    ),
                    title: Text(
                      context.l10n.addServer,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (servers.isEmpty)
              ListTile(title: Text(context.l10n.noServersConfigured))
            else ...[
              RadioGroup<int>(
                groupValue: activeId,
                onChanged: (v) {
                  if (v != null) settings.setActiveServer(v);
                },
                child: Column(
                  children: servers
                      .map((server) {
                        return ListTile(
                            leading: Icon(_serverIcon(server.type)),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    server.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              server.serverUrl?.isNotEmpty == true
                                  ? server.serverUrl!
                                  : _serverTypeLabel(context, server.type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                                        final err = await settings
                                            .testServerConnection(server);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(err == null
                                                ? context.l10n.connectionSuccess
                                                : "${context.l10n.connectionFailed}: $err"),
                                          ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => AddServerDialog(
                                        serverType: server.type,
                                        existing: server,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(context.l10n.deleteServer),
                                          content: Text(context.l10n.deleteServerConfirm),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(false),
                                              child: Text(context.l10n.cancel),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(true),
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
                                ]
                              ],
                            ),
                          );
                      })
                      .toList(),
                ),
              ),
              Obx(() {
                final active = settings.activeServer;
                final isNonYouTube =
                    active != null && active.type != ServerType.youtubeMusic;
                if (!isNonYouTube) return const SizedBox.shrink();
                return ListTile(
                  title: Text(context.l10n.resyncLibraryNow),
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
            ],
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
    final theme = Theme.of(context);
    return [
      Obx(() => ListTile(
            title: Text(context.l10n.autoDownFavSong),
            subtitle: Text(context.l10n.autoDownFavSongDes),
            trailing: CustSwitch(
              value: settings.autoDownloadFavoriteSongEnabled.value,
              onChanged: settings.toggleAutoDownloadFavoriteSong,
            ),
          )),
      ListTile(
        title: Text(context.l10n.downloadingFormat),
        subtitle: Text(context.l10n.downloadingFormatDes),
        trailing: Obx(
          () => DropdownButton(
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            style: theme.textTheme.bodyMedium,
            dropdownColor: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
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
        title: Text(context.l10n.downloadLocation),
        subtitle: Obx(() => Text(settings.isCurrentPathsupportDownDir
            ? "In App storage directory"
            : settings.downloadLocationPath.value)),
        trailing: TextButton(
          onPressed: settings.resetDownloadLocation,
          child: Text(context.l10n.reset),
        ),
        onTap: settings.setDownloadLocation,
      ),
      if (GetPlatform.isAndroid)
        ListTile(
          title: Text(context.l10n.exportDowloadedFiles),
          subtitle: Text(context.l10n.exportDowloadedFilesDes),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const ExportFileDialog(),
          ).whenComplete(() => Get.delete<ExportFileDialogController>()),
        ),
      if (GetPlatform.isAndroid)
        ListTile(
          title: Text(context.l10n.exportedFileLocation),
          subtitle: Obx(() => Text(settings.exportLocationPath.value)),
          onTap: settings.setExportedLocation,
        ),
    ];
  }

  List<Widget> _buildBackup(BuildContext context) {
    return [
      ListTile(
        title: Text(context.l10n.backupAppData),
        subtitle: Text(context.l10n.backupSettingsAndPlaylistsDes),
        onTap: () => showDialog(
          context: context,
          builder: (_) => const BackupDialog(),
        ).whenComplete(() => Get.delete<BackupDialogController>()),
      ),
      ListTile(
        title: Text(context.l10n.restoreAppData),
        subtitle: Text(context.l10n.restoreSettingsAndPlaylistsDes),
        onTap: () => showDialog(
          context: context,
          builder: (_) => const RestoreDialog(),
        ).whenComplete(() => Get.delete<RestoreDialogController>()),
      ),
    ];
  }

  List<Widget> _buildMisc(
      BuildContext context, SettingsScreenController settings) {
    final isDesktop = GetPlatform.isDesktop;
    return [
      Obx(() => ListTile(
            title: Text(context.l10n.playbackDiagnosticsRelease),
            subtitle: const Text(
                "Record bounded playback/network events for troubleshooting."),
            trailing: CustSwitch(
              value: settings.playbackDiagnosticsEnabled.value,
              onChanged: settings.togglePlaybackDiagnostics,
            ),
          )),
      ListTile(
        title: Text(context.l10n.viewPlaybackDiagnostics),
        subtitle: Text(context.l10n.viewPlaybackDiagnosticsSubtitle),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _PlaybackDiagnosticsPage(),
          ),
        ),
      ),
      ListTile(
        title: Text(context.l10n.clearPlaybackDiagnostics),
        subtitle: Text(context.l10n.clearPlaybackDiagnosticsSubtitle),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Discord Rich Presence',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Obx(() => ListTile(
              leading: const Icon(Icons.discord, size: 20),
              title: const Text('Show Discord activity'),
              subtitle: const Text(
                  'Display the current song as your Discord status.'),
              trailing: CustSwitch(
                value: settings.discordRpcEnabled.value,
                onChanged: settings.toggleDiscordRpc,
              ),
            )),
        Obx(() => ListTile(
              leading: const Icon(Icons.vpn_key_outlined, size: 20),
              title: const Text('Discord Application ID'),
              subtitle: Text(
                settings.discordAppId.value.isEmpty
                    ? 'Not set — create one at discord.com/developers/applications'
                    : settings.discordAppId.value,
                style: TextStyle(
                  color: settings.discordAppId.value.isEmpty
                      ? Theme.of(context).colorScheme.error.withValues(alpha: 0.7)
                      : null,
                ),
              ),
              onTap: () => _showDiscordAppIdDialog(context, settings),
            )),
        Obx(() => ListTile(
              leading: const Icon(Icons.bolt_outlined, size: 20),
              title: const Text('Test Discord connection'),
              subtitle: Text(
                settings.discordAppId.value.isEmpty
                    ? 'Set an Application ID first'
                    : 'Send a test activity to Discord',
                style: TextStyle(
                  color: settings.discordAppId.value.isEmpty
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
              enabled: settings.discordAppId.value.isNotEmpty,
              onTap: () => _testDiscordRpc(context, settings),
            )),
      ],
      ListTile(
        title: Text(context.l10n.resetToDefault),
        subtitle: Text(context.l10n.resetToDefaultDes),
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

  void _testDiscordRpc(
      BuildContext context, SettingsScreenController settings) async {
    if (!Get.isRegistered<DiscordRpcService>()) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(context, 'Discord RPC is not available on this platform',
            size: SnackBarSize.BIG),
      );
      return;
    }

    final svc = Get.find<DiscordRpcService>();
    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(context, 'Testing Discord connection...', size: SnackBarSize.BIG),
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

  void _showDiscordAppIdDialog(
      BuildContext context, SettingsScreenController settings) {
    final controller =
        TextEditingController(text: settings.discordAppId.value);
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
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Application ID',
                  border: OutlineInputBorder(),
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

  List<Widget> _buildInfo(
      BuildContext context, SettingsScreenController settings) {
    return [
      Obx(() => ListTile(
            leading: const Icon(Icons.system_update_alt, size: 20),
            title: Text(context.l10n.checkForUpdatesOnStartup),
            trailing: CustSwitch(
              value: settings.checkForUpdatesOnStartup.value,
              onChanged: settings.toggleCheckForUpdatesOnStartup,
            ),
          )),
      ListTile(
        leading: const Icon(Icons.system_update, size: 20),
        title: Text(context.l10n.checkForUpdates),
        onTap: () async {
          final upToDate = context.l10n.upToDate;
          final checking = context.l10n.checkingForUpdates;
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
        leading: const Icon(Icons.public, size: 20),
        title: Text(context.l10n.openGitlab),
        subtitle: Text(context.l10n.gitlabDes),
        onTap: () => launchUrl(
          Uri.parse('https://gitlab.com/Openlyst/doudou/'),
          mode: LaunchMode.externalApplication,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onLongPress: () {
                if (kIsPlayStore && !_ytmProviderUnlocked) {
                  _ytmProviderUnlocked = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Additional providers unlocked')),
                  );
                }
              },
              child: Image.asset(
                'assets/icons/icon.png',
                width: 48,
                height: 48,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.82)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.28),
          ),
          Theme(
            data: theme.copyWith(
              listTileTheme: ListTileThemeData(
                iconColor: colorScheme.onSurface.withValues(alpha: 0.78),
                textColor: colorScheme.onSurface,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: children,
              ),
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SettingsCard(
                    icon: icon,
                    title: title,
                    children: children,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Material(
        color:
            theme.dialogTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.themeMode,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      radioWidget(
                        context: context,
                        label: context.l10n.dynamicTheme,
                        controller: settingsController,
                        value: ThemeType.dynamic,
                      ),
                      radioWidget(
                          context: context,
                          label: context.l10n.systemDefault,
                          controller: settingsController,
                          value: ThemeType.system),
                      radioWidget(
                          context: context,
                          label: context.l10n.dark,
                          controller: settingsController,
                          value: ThemeType.dark),
                      radioWidget(
                          context: context,
                          label: context.l10n.oled,
                          controller: settingsController,
                          value: ThemeType.oled),
                      radioWidget(
                          context: context,
                          label: context.l10n.light,
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
                      child: Text(context.l10n.cancel,
                          style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                    )),
              )
            ],
          ),
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
                  context.l10n.setDiscoverContent,
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
                        context: context,
                        label: context.l10n.quickpicks,
                        controller: settingsController,
                        value: "QP"),
                    radioWidget(
                        context: context,
                        label: context.l10n.topmusicvideos,
                        controller: settingsController,
                        value: "TMV"),
                    radioWidget(
                        context: context,
                        label: context.l10n.trending,
                        controller: settingsController,
                        value: "TR"),
                    radioWidget(
                        context: context,
                        label: context.l10n.basedOnLast,
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
                    child: Text(context.l10n.cancel,
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
    final types = ServerType.values.where((t) {
      if (t == ServerType.youtubeMusic &&
          kIsPlayStore &&
          !_ytmProviderUnlocked) {
        return false;
      }
      return true;
    }).toList();

    // TV mode: bigger tiles with focus highlights
    final isTv = Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value;
    if (isTv) {
      return _TvAddProviderDialog(types: types);
    }

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
                    context.l10n.addServer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < types.length; i++) ...[
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(_serverIcon(types[i])),
                title: Text(_serverTypeLabel(context, types[i])),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => Navigator.of(context).pop(types[i]),
              ),
              if (i < types.length - 1)
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancel),
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

class _PlaybackDiagnosticsPage extends StatefulWidget {
  const _PlaybackDiagnosticsPage();

  @override
  State<_PlaybackDiagnosticsPage> createState() =>
      _PlaybackDiagnosticsPageState();
}

class _PlaybackDiagnosticsPageState extends State<_PlaybackDiagnosticsPage> {
  static const int _maxShownEvents = 400;
  bool _prettyFormat = false;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsScreenController>();
    final text = settings.getPlaybackDiagnosticsText(
      limit: _maxShownEvents,
      pretty: _prettyFormat,
    );
    final count = settings.playbackDiagnosticsCount;
    final isEmpty = text.trim().isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.playbackDiagnostics),
        actions: [
          IconButton(
            tooltip: context.l10n.toggleFormat,
            onPressed: () => setState(() => _prettyFormat = !_prettyFormat),
            icon: Icon(_prettyFormat ? Icons.code : Icons.notes),
          ),
          IconButton(
            tooltip: context.l10n.copyDiagnostics,
            onPressed: () async {
              final copied = await settings.copyPlaybackDiagnosticsToClipboard(
                limit: _maxShownEvents,
                pretty: _prettyFormat,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(copied
                      ? "Diagnostics copied to clipboard"
                      : "No diagnostics to copy"),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: "Refresh",
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Events: $count (showing up to $_maxShownEvents)",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: isEmpty
                    ? const Center(
                        child: Text(
                          "No diagnostics yet.\nEnable diagnostics and reproduce the issue.",
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: SelectableText(
                          text,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddServerDialogState extends State<AddServerDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late String _protocol;

  @override
  void initState() {
    super.initState();
    var existingUrl = widget.existing?.serverUrl ?? '';
    if (existingUrl.startsWith('http://')) {
      _protocol = 'http';
      existingUrl = existingUrl.substring(7);
    } else if (existingUrl.startsWith('https://')) {
      _protocol = 'https';
      existingUrl = existingUrl.substring(8);
    } else {
      _protocol = 'https';
    }
    _urlController = TextEditingController(text: existingUrl);
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

  String _buildServerUrl() {
    var url = _urlController.text.trim();
    url = url.replaceFirst(RegExp(r'^https?://'), '');
    if (url.isEmpty) return '';
    return '$_protocol://$url';
  }

  bool get _needsCredentials =>
      widget.serverType == ServerType.subsonic ||
      widget.serverType == ServerType.jellyfin ||
      widget.serverType == ServerType.plex;

  String _title(BuildContext context) {
    final l10n = context.l10n;
    if (widget.existing != null) return l10n.editServer;
    switch (widget.serverType) {
      case ServerType.youtubeMusic:
        return '${l10n.addServer} - ${l10n.youtubeMusic}';
      case ServerType.subsonic:
        return '${l10n.addServer} - ${l10n.subsonic}';
      case ServerType.jellyfin:
        return '${l10n.addServer} - ${l10n.jellyfin}';
      case ServerType.plex:
        return '${l10n.addServer} - ${l10n.plex}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // TV mode: show staged wizard instead of the cramped dialog
    if (Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value) {
      return _TvAddServerWizard(
        serverType: widget.serverType,
        existing: widget.existing,
        urlController: _urlController,
        usernameController: _usernameController,
        passwordController: _passwordController,
        protocol: _protocol,
        onProtocolChanged: (v) => setState(() => _protocol = v),
        buildServerUrl: _buildServerUrl,
        needsCredentials: _needsCredentials,
        title: _title(context),
      );
    }

    final controller = Get.find<SettingsScreenController>();
    final l10n = context.l10n;
    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_needsCredentials) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _protocol,
                      decoration: const InputDecoration(
                        labelText: 'Protocol',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                        DropdownMenuItem(value: 'http', child: Text('HTTP')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _protocol = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: l10n.serverUrl,
                        hintText: 'example.com',
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              if (widget.serverType != ServerType.plex) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: l10n.username),
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: widget.serverType == ServerType.plex
                      ? l10n.plexToken
                      : l10n.password,
                ),
                obscureText: true,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                l10n.youtubeMusicNoLogin,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (widget.existing != null) {
                      if (_needsCredentials) {
                        controller.updateServer(
                          widget.existing!.id,
                          serverUrl: _buildServerUrl(),
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      }
                    } else {
                      if (_needsCredentials) {
                        final serverUrl = _buildServerUrl();
                        if (serverUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.serverUrlRequired)),
                          );
                          return;
                        }
                        controller.addServerWithCredentials(
                          widget.serverType,
                          serverUrl: serverUrl,
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      } else {
                        controller
                            .addServerWithCredentials(widget.serverType);
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(widget.existing != null ? l10n.save : l10n.add),
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
    {required BuildContext context,
    required String label,
    required SettingsScreenController controller,
    required value}) {
  return Obx(() => ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        onTap: () {
          if (value.runtimeType == ThemeType) {
            controller.onThemeChange(value);
          } else {
            controller.onContentChange(value);
            Navigator.of(context).pop();
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
                    Navigator.of(context).pop();
                  },
            child: Radio(value: value)),
        title: Text(label),
      ));
}

/// TV-optimized server type picker with large focusable tiles.
class _TvAddProviderDialog extends StatelessWidget {
  const _TvAddProviderDialog({required this.types});

  final List<ServerType> types;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: FocusTraversalGroup(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.addServer,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              for (int i = 0; i < types.length; i++) ...[
                TvFocusHighlight(
                  borderRadius: 12,
                  autofocus: i == 0,
                  debugLabel: 'ServerType_${types[i].name}',
                  onSelect: () => Navigator.of(context).pop(types[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(_serverIcon(types[i]), size: 32),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            _serverTypeLabel(context, types[i]),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 28),
                      ],
                    ),
                  ),
                ),
                if (i < types.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: TvFocusHighlight(
                  borderRadius: 8,
                  debugLabel: 'CancelProvider',
                  onSelect: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      l10n.cancel,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TV-optimized staged wizard for adding/editing a server.
/// Each field gets its own full-screen stage so D-pad navigation is simple
/// and text input is large enough for a 10-foot UI.
class _TvAddServerWizard extends StatefulWidget {
  const _TvAddServerWizard({
    required this.serverType,
    this.existing,
    required this.urlController,
    required this.usernameController,
    required this.passwordController,
    required this.protocol,
    required this.onProtocolChanged,
    required this.buildServerUrl,
    required this.needsCredentials,
    required this.title,
  });

  final ServerType serverType;
  final SettingsServer? existing;
  final TextEditingController urlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String protocol;
  final ValueChanged<String> onProtocolChanged;
  final String Function() buildServerUrl;
  final bool needsCredentials;
  final String title;

  @override
  State<_TvAddServerWizard> createState() => _TvAddServerWizardState();
}

class _TvAddServerWizardState extends State<_TvAddServerWizard> {
  int _stage = 0;
  late int _maxStage;

  @override
  void initState() {
    super.initState();
    // Stages: 0=protocol, 1=url, 2=username (if needed), 3=password, 4=confirm
    // For Plex: no username, just token
    // For YouTube Music: no credentials at all
    if (!widget.needsCredentials) {
      _maxStage = 0; // just confirm
    } else if (widget.serverType == ServerType.plex) {
      _maxStage = 2; // protocol, url, token
    } else {
      _maxStage = 3; // protocol, url, username, password
    }
  }

  void _next() {
    if (_stage < _maxStage) {
      setState(() => _stage++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_stage > 0) {
      setState(() => _stage--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    final controller = Get.find<SettingsScreenController>();
    final l10n = context.l10n;

    if (widget.needsCredentials) {
      final serverUrl = widget.buildServerUrl();
      if (serverUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.serverUrlRequired)),
        );
        return;
      }

      if (widget.existing != null) {
        controller.updateServer(
          widget.existing!.id,
          serverUrl: serverUrl,
          username: widget.usernameController.text,
          password: widget.passwordController.text,
        );
      } else {
        controller.addServerWithCredentials(
          widget.serverType,
          serverUrl: serverUrl,
          username: widget.usernameController.text,
          password: widget.passwordController.text,
        );
      }
    } else {
      // YouTube Music — no creds needed
      if (widget.existing != null) {
        // nothing to update for YTM
      } else {
        controller.addServerWithCredentials(widget.serverType);
      }
    }
    Navigator.of(context).pop();
  }

  String _stageTitle() {
    final l10n = context.l10n;
    if (!widget.needsCredentials) return l10n.youtubeMusicNoLogin;
    switch (_stage) {
      case 0:
        return 'Protocol';
      case 1:
        return l10n.serverUrl;
      case 2:
        return widget.serverType == ServerType.plex ? l10n.plexToken : l10n.username;
      case 3:
        return l10n.password;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: FocusTraversalGroup(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with title and stage indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.needsCredentials)
                    Text(
                      'Step ${_stage + 1} of ${_maxStage + 1}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Stage title
              Text(
                _stageTitle(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Stage content
              Expanded(
                flex: 0,
                child: _buildStageContent(context),
              ),
              const SizedBox(height: 40),
              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TvFocusHighlight(
                    borderRadius: 8,
                    debugLabel: 'BackBtn',
                    onSelect: _back,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text(
                        _stage == 0 ? l10n.cancel : 'Back',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  TvFocusHighlight(
                    borderRadius: 8,
                    autofocus: true,
                    debugLabel: 'NextBtn',
                    onSelect: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _stage == _maxStage
                            ? (widget.existing != null ? l10n.save : l10n.add)
                            : 'Next',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (!widget.needsCredentials) {
      // YouTube Music — just a message
      return Text(
        l10n.youtubeMusicNoLogin,
        style: theme.textTheme.titleMedium,
      );
    }

    switch (_stage) {
      case 0:
        // Protocol selection — two big buttons
        return Row(
          children: [
            Expanded(
              child: _TvProtocolChoice(
                label: 'HTTPS',
                selected: widget.protocol == 'https',
                onSelect: () {
                  widget.onProtocolChanged('https');
                  _next();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TvProtocolChoice(
                label: 'HTTP',
                selected: widget.protocol == 'http',
                onSelect: () {
                  widget.onProtocolChanged('http');
                  _next();
                },
              ),
            ),
          ],
        );

      case 1:
        // URL input
        return TextField(
          controller: widget.urlController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.serverUrl,
            labelStyle: const TextStyle(fontSize: 18),
            hintText: 'example.com',
            hintStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      case 2:
        if (widget.serverType == ServerType.plex) {
          // Plex token
          return TextField(
            controller: widget.passwordController,
            autofocus: true,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: l10n.plexToken,
              labelStyle: const TextStyle(fontSize: 18),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
          );
        }
        // Username
        return TextField(
          controller: widget.usernameController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.username,
            labelStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      case 3:
        // Password
        return TextField(
          controller: widget.passwordController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.password,
            labelStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _TvProtocolChoice extends StatelessWidget {
  const _TvProtocolChoice({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusHighlight(
      borderRadius: 12,
      onSelect: onSelect,
      debugLabel: 'Protocol_$label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.outline : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
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

String _serverTypeLabel(BuildContext context, ServerType type) {
  final l10n = context.l10n;
  return switch (type) {
    ServerType.youtubeMusic => l10n.youtubeMusic,
    ServerType.subsonic => l10n.subsonic,
    ServerType.jellyfin => l10n.jellyfin,
    ServerType.plex => l10n.plex,
  };
}
