import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/utils/theme_controller.dart';
import '/ui/widgets/cust_switch.dart';
import '../settings_screen_controller.dart';
import '../components/custom_expansion_tile.dart';

class SettingsPersonalisationSection extends StatelessWidget {
  const SettingsPersonalisationSection(
      {super.key, this.onThemeTap, this.expansionKey, this.onExpansionChanged});
  final VoidCallback? onThemeTap;
  final Key? expansionKey;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    final isDesktop = GetPlatform.isDesktop;
    return CustomExpansionTile(
      title: context.l10n.personalisation,
      icon: Icons.palette_outlined,
      expansionKey: expansionKey,
      onExpansionChanged: onExpansionChanged,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.themeMode),
          subtitle: Obx(
            () => Text(
                settingsController.themeModetype.value == ThemeType.dynamic
                    ? context.l10n.dynamicTheme
                    : settingsController.themeModetype.value == ThemeType.system
                        ? context.l10n.systemDefault
                        : settingsController.themeModetype.value ==
                                ThemeType.dark
                            ? context.l10n.dark
                            : settingsController.themeModetype.value ==
                                    ThemeType.oled
                                ? context.l10n.oled
                                : context.l10n.light,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    )),
          ),
          onTap: onThemeTap ?? () {},
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.lyricsDynamicColor),
          subtitle: Text(
            context.l10n.lyricsDynamicColorDes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          trailing: Obx(
            () => CustSwitch(
              value: settingsController.lyricsDynamicColorEnabled.value,
              onChanged: settingsController.setLyricsDynamicColorEnabled,
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.syncedLyricsHighlightStyle),
          subtitle: Text(
            context.l10n.syncedLyricsHighlightStyleDes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          trailing: Obx(
            () => DropdownButton<SyncedLyricsHighlightStyle>(
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: Theme.of(context).textTheme.bodyMedium,
              value: settingsController.syncedLyricsHighlightStyle.value,
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
              onChanged: (val) {
                if (val != null) {
                  settingsController.setSyncedLyricsHighlightStyle(val);
                }
              },
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.language),
          subtitle: Text(context.l10n.languageDes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
          trailing: Obx(
            () => DropdownButton(
              menuMaxHeight: Get.height - 250,
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: Theme.of(context).textTheme.bodyMedium,
              value: settingsController.currentAppLanguageCode.value,
              items: supportedLocalesDisplay.entries
                  .map((lang) => DropdownMenuItem(
                        value: lang.key,
                        child: Text(lang.value),
                      ))
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              selectedItemBuilder: (context) =>
                  supportedLocalesDisplay.entries.map<Widget>((item) {
                return Container(
                  alignment: Alignment.centerRight,
                  constraints: const BoxConstraints(minWidth: 50),
                  child: Text(item.value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: settingsController.setAppLanguage,
            ),
          ),
        ),
        if (!isDesktop)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(context.l10n.playerUi),
            subtitle: Text(context.l10n.playerUiDes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    )),
            trailing: Obx(
              () => DropdownButton(
                dropdownColor: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                underline: const SizedBox.shrink(),
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: Theme.of(context).textTheme.bodyMedium,
                value: settingsController.playerUi.value,
                items: [
                  DropdownMenuItem(value: 0, child: Text(context.l10n.standard)),
                  DropdownMenuItem(value: 1, child: Text(context.l10n.gesture)),
                ],
                onChanged: settingsController.setPlayerUi,
              ),
            ),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.animationSpeed),
          subtitle: Text(
            context.l10n.animationSpeedDes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          trailing: Obx(
            () => DropdownButton<AnimationSpeed>(
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: Theme.of(context).textTheme.bodyMedium,
              value: settingsController.animationSpeed.value,
              items: [
                DropdownMenuItem(
                  value: AnimationSpeed.off,
                  child: Text(context.l10n.animationSpeedOff),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.fast,
                  child: Text(context.l10n.animationSpeedFast),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.normal,
                  child: Text(context.l10n.animationSpeedNormal),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.slow,
                  child: Text(context.l10n.animationSpeedSlow),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  settingsController.setAnimationSpeed(val);
                }
              },
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(context.l10n.enableSlidableAction),
          subtitle: Text(context.l10n.enableSlidableActionDes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
          trailing: Obx(
            () => CustSwitch(
                value: settingsController.slidableActionEnabled.isTrue,
                onChanged: settingsController.toggleSlidableAction),
          ),
        ),
      ],
    );
  }
}
