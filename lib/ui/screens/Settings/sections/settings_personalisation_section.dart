import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

import '/ui/utils/theme_controller.dart';
import '/ui/widgets/cust_switch.dart';
import '/utils/lang_mapping.dart';
import '../components/custom_expansion_tile.dart';
import '../settings_screen_controller.dart';

class SettingsPersonalisationSection extends StatelessWidget {
  const SettingsPersonalisationSection(
      {super.key,
      this.onThemeTap,
      this.expansionKey,
      this.onExpansionChanged});
  final VoidCallback? onThemeTap;
  final Key? expansionKey;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    final themeController = Get.find<ThemeController>();
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
                    : settingsController.themeModetype.value ==
                            ThemeType.dynamicColor
                        ? "dynamicColor".tr
                        : settingsController.themeModetype.value ==
                                ThemeType.system
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
        Obx(() {
          if (settingsController.themeModetype.value !=
              ThemeType.dynamicColor) {
            return const SizedBox.shrink();
          }
          final color = themeController.dynamicColor.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text("dynamicColor".tr),
                subtitle: Text(
                  "dynamicColorDes".tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                trailing: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final initial = themeController.dynamicColor.value;
                    Color tempColor = initial;
                    await showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Text("pickDynamicColor".tr),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    Colors.deepPurple,
                                    Colors.indigo,
                                    Colors.blueGrey,
                                    Colors.teal.shade400,
                                    Colors.green.shade600,
                                    Colors.amber.shade700,
                                    Colors.deepOrange.shade400,
                                    Colors.brown.shade500,
                                    Colors.grey.shade700,
                                  ]
                                      .map(
                                        (c) => GestureDetector(
                                          onTap: () {
                                            themeController.setDynamicColor(c);
                                            Navigator.of(dialogContext).pop();
                                          },
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                    alpha: 0.8),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () async {
                                      await showDialog(
                                        context: dialogContext,
                                        builder: (ctx) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                            title: Text("pickDynamicColor".tr),
                                            content: SingleChildScrollView(
                                              child: ColorPicker(
                                                pickerColor: tempColor,
                                                onColorChanged: (c) {
                                                  tempColor = c;
                                                },
                                                labelTypes: const [],
                                                pickerAreaBorderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: Text("cancel".tr),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  themeController
                                                      .setDynamicColor(
                                                          tempColor);
                                                  Navigator.of(ctx).pop();
                                                  Navigator.of(dialogContext)
                                                      .pop();
                                                },
                                                child: Text("apply".tr),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: Text("advanced".tr),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeController.dynamicColor.value.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("change".tr, style: TextStyle(color: themeController.dynamicColor.value, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
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
            ],
          );
        }),
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
                  child: Text(item.value, style: const TextStyle(fontWeight: FontWeight.w600)),
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

