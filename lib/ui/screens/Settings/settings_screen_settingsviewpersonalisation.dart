part of 'settings_screen.dart';

mixin _SettingsViewPersonalisationMixin on __SettingsViewStateBase {
  List<Widget> _buildPersonalisation(
    BuildContext context,
    SettingsScreenController settings,
  ) {
    final isDesktop = GetPlatform.isDesktop;

    return [
      _SettingsListTile(
        title: context.l10n.themeMode,
        subtitle:
            Obx(() => Text(_themeModeLabel(context, settings.themeModetype.value))),
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
      if (isDesktop)
        _SettingsListTile(
          title: context.l10n.nowPlayingLayout,
          subtitle: context.l10n.nowPlayingLayoutDes,
          trailing: Obx(() => _SettingsDropdown<NowPlayingLayout>(
                value: settings.nowPlayingLayout.value,
                items: [
                  (
                    NowPlayingLayout.sideView,
                    context.l10n.nowPlayingLayoutSideView
                  ),
                  (
                    NowPlayingLayout.playBar,
                    context.l10n.nowPlayingLayoutPlayBar
                  ),
                ],
                onChanged: settings.setNowPlayingLayout,
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

  String _themeModeLabel(BuildContext context, ThemeType type) {
    final l10n = context.l10n;
    return switch (type) {
      ThemeType.dynamic => l10n.dynamicTheme,
      ThemeType.system => l10n.systemDefault,
      ThemeType.dark => l10n.dark,
      ThemeType.oled => l10n.oled,
      ThemeType.light => l10n.light,
    };
  }

}
