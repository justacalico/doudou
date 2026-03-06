import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/Home/home_screen_controller.dart';
import 'common_dialog_widget.dart';

class NewVersionDialog extends StatelessWidget {
  const NewVersionDialog({super.key, this.latestVersion});

  final String? latestVersion;

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      child: Container(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 400),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              context.l10n.newVersionAvailable,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (latestVersion != null && latestVersion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${context.l10n.version} $latestVersion',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SizedBox.square(
                  dimension: 100,
                  child: FittedBox(
                    child: FloatingActionButton(
                      onPressed: () {
                        launchUrl(
                          Uri.parse('https://openlyst.ink/apps/doudou'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Icon(
                        Icons.download,
                        size: 30,
                      ),
                    ),
                  ),
                )),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GetX<HomeScreenController>(builder: (controller) {
                    return Checkbox(
                        value: controller.showVersionDialog.isFalse,
                        onChanged: (val) {
                          controller.onChangeVersionVisibility(val ?? false);
                        },
                        shape: const CircleBorder());
                  }),
                  Text(context.l10n.dontShowInfoAgain)
                ],
              ),
            ),
            Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).textTheme.titleLarge!.color,
                    borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: Text(context.l10n.dismiss,
                        style: TextStyle(color: Theme.of(context).canvasColor)),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ))
          ],
        ),
      ),
    );
  }
}
