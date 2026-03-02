// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shell_controller.dart';

enum SnackBarSize { BIG, MEDIUM, SMALL }

SnackBar snackbar(BuildContext context, String text,
    {SnackBarSize size = SnackBarSize.MEDIUM,
    Duration duration = const Duration(seconds: 1),
    bool top = false}) {
  final scrWidth = MediaQuery.of(context).size.width;
  final hrMargin = size == SnackBarSize.BIG
      ? (scrWidth - 300) / 2
      : size == SnackBarSize.MEDIUM
          ? (scrWidth - 200) / 2
          : (scrWidth - 100) / 2;
  return SnackBar(
    backgroundColor: Theme.of(context).colorScheme.secondary,
    content: Center(
      child: Text(
        text,
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black),
      ),
    ),
    margin: EdgeInsets.only(
        bottom: top ? MediaQuery.of(context).size.height * 0.8 : 100,
        left: hrMargin,
        right: hrMargin),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
