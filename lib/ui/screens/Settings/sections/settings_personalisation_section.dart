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
      icon: Icons.palette,
      expansionKey: expansionKey,
      onExpansionChanged: onExpansionChanged,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
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
                style: Theme.of(context).textTheme.bodyMedium),
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
                contentPadding: const EdgeInsets.only(left: 5, right: 10),
                title: Text("dynamicColor".tr),
                subtitle: Text(
                  "dynamicColorDes".tr,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: InkWell(
              onTap: () async {
                final initial = themeController.dynamicColor.value;
                Color tempColor = initial;
                await showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: Text("pickDynamicColor".tr),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
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
                                        width: 28,
                                        height: 28,
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
                                        title: Text("pickDynamicColor".tr),
                                        content: SingleChildScrollView(
                                          child: ColorPicker(
                                            pickerColor: tempColor,
                                            onColorChanged: (c) {
                                              tempColor = c;
                                            },
                                            labelTypes: const [],
                                            pickerAreaBorderRadius:
                                                BorderRadius.circular(8),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
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
                  Text("change".tr),
                ],
              ),
            ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 5, right: 10),
                title: Text("lyricsDynamicColor".tr),
                subtitle: Text(
                  "lyricsDynamicColorDes".tr,
                  style: Theme.of(context).textTheme.bodyMedium,
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
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          title: Text("language".tr),
          subtitle: Text("languageDes".tr,
              style: Theme.of(context).textTheme.bodyMedium),
          trailing: Obx(
            () => DropdownButton(
              menuMaxHeight: Get.height - 250,
              dropdownColor: Theme.of(context).cardColor,
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
                  child: Text(item.value),
                );
              }).toList(),
              onChanged: settingsController.setAppLanguage,
            ),
          ),
        ),
        if (!isDesktop)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 5, right: 10),
            title: Text("playerUi".tr),
            subtitle: Text("playerUiDes".tr,
                style: Theme.of(context).textTheme.bodyMedium),
            trailing: Obx(
              () => DropdownButton(
                dropdownColor: Theme.of(context).cardColor,
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
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          title: Text("animationSpeed".tr),
          subtitle: Text(
            "animationSpeedDes".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Obx(
            () => DropdownButton<AnimationSpeed>(
              dropdownColor: Theme.of(context).cardColor,
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
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          title: Text("enableSlidableAction".tr),
          subtitle: Text("enableSlidableActionDes".tr,
              style: Theme.of(context).textTheme.bodyMedium),
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

