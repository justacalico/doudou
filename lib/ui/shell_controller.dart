import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ShellController extends GetxController {
  final useBottomNav = false.obs;
  BuildContext? overlayContext;

  void setUseBottomNav(bool value) {
    if (useBottomNav.value != value) {
      useBottomNav.value = value;
    }
  }

  void setOverlayContext(BuildContext? context) {
    overlayContext = context;
  }

  BuildContext? get overlayContextOrFallback => overlayContext ?? Get.context;
}
