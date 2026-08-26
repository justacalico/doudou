part of 'settings_screen.dart';

mixin _SettingsViewPlaybackMixin on __SettingsViewStateBase {
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

}
