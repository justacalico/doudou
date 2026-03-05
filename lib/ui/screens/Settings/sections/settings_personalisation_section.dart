import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/utils/theme_controller.dart';
import '/ui/widgets/cust_switch.dart';
import '/utils/lang_mapping.dart';
import '../components/custom_expansion_tile.dart';
import '../settings_screen_controller.dart';

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
      title: "personalisation".tr,
      icon: Icons.palette_outlined,
      expansionKey: expansionKey,
      onExpansionChanged: onExpansionChanged,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text("themeMode".tr),
          subtitle: Obx(
            () => Text(
                settingsController.themeModetype.value == ThemeType.dynamic
                    ? "dynamic".tr
                    : settingsController.themeModetype.value == ThemeType.system
                        ? "systemDefault".tr
                        : settingsController.themeModetype.value ==
                                ThemeType.dark
                            ? "dark".tr
                            : settingsController.themeModetype.value ==
                                    ThemeType.oled
                                ? "oled".tr
                                : "light".tr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    )),
          ),
          onTap: onThemeTap ?? () {},
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text("lyricsDynamicColor".tr),
          subtitle: Text(
            "lyricsDynamicColorDes".tr,
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
          title: Text("syncedLyricsHighlightStyle".tr),
          subtitle: Text(
            "syncedLyricsHighlightStyleDes".tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          trailing: Obx(
            () => DropdownButton<SyncedLyricsHighlightStyle>(
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              underline: const SizedBox.shrink(),
              value: settingsController.syncedLyricsHighlightStyle.value,
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
          title: Text("language".tr),
          subtitle: Text("languageDes".tr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
          trailing: Obx(
            () => DropdownButton(
              menuMaxHeight: Get.height - 250,
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.titleSmall,
              value: settingsController.currentAppLanguageCode.value,
              items: langMap.entries
                  .map((lang) => DropdownMenuItem(
                        value: lang.key,
                        child: Text(lang.value),
                      ))
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              selectedItemBuilder: (context) =>
                  langMap.entries.map<Widget>((item) {
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
            title: Text("playerUi".tr),
            subtitle: Text("playerUiDes".tr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    )),
            trailing: Obx(
              () => DropdownButton(
                dropdownColor: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                underline: const SizedBox.shrink(),
                value: settingsController.playerUi.value,
                items: [
                  DropdownMenuItem(value: 0, child: Text("standard".tr)),
                  DropdownMenuItem(value: 1, child: Text("gesture".tr)),
                ],
                onChanged: settingsController.setPlayerUi,
              ),
            ),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text("animationSpeed".tr),
          subtitle: Text(
            "animationSpeedDes".tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          trailing: Obx(
            () => DropdownButton<AnimationSpeed>(
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              underline: const SizedBox.shrink(),
              value: settingsController.animationSpeed.value,
              items: [
                DropdownMenuItem(
                  value: AnimationSpeed.off,
                  child: Text("animationSpeedOff".tr),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.fast,
                  child: Text("animationSpeedFast".tr),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.normal,
                  child: Text("animationSpeedNormal".tr),
                ),
                DropdownMenuItem(
                  value: AnimationSpeed.slow,
                  child: Text("animationSpeedSlow".tr),
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
          title: Text("enableSlidableAction".tr),
          subtitle: Text("enableSlidableActionDes".tr,
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
