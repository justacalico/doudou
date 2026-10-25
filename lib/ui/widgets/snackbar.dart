// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design/doudou_colors.dart';
import '../shell_controller.dart';

enum SnackBarSize { BIG, MEDIUM, SMALL }

SnackBar snackbar(BuildContext context, String text,
    {SnackBarSize size = SnackBarSize.MEDIUM,
    Duration duration = const Duration(seconds: 1),
    bool top = false}) {
  final scrWidth = MediaQuery.of(context).size.width;
  final barWidth = size == SnackBarSize.BIG
      ? 300.0
      : size == SnackBarSize.MEDIUM
          ? 220.0
          : 120.0;
  final hrMargin = ((scrWidth - barWidth) / 2).clamp(16.0, scrWidth);
  return SnackBar(
    backgroundColor: context.doudouColors.surfaceModal,
    content: Center(
      child: Text(
        text,
        style: TextStyle(color: context.doudouColors.textPrimary),
      ),
    ),
    margin: EdgeInsets.only(
        bottom: top ? MediaQuery.of(context).size.height * 0.8 : 100,
        left: hrMargin,
        right: hrMargin),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.doudouColors.borderSubtle)),
  );
}

void showAppSnackBar(String text,
    {SnackBarSize size = SnackBarSize.MEDIUM,
    Duration duration = const Duration(seconds: 1),
    bool top = false}) {
  BuildContext? ctx;
  if (Get.isRegistered<ShellController>()) {
    ctx = Get.find<ShellController>().overlayContext;
  }
  ctx ??= Get.context;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
      snackbar(ctx, text, size: size, duration: duration, top: top));
}
