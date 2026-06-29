import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class ShellController extends GetxController {
  final useBottomNav = false.obs;
  BuildContext? overlayContext;

  // Now playing side panel (desktop only)
  static const double _minPanelWidth = 280.0;
  static const double _maxPanelWidth = 600.0;
  static const double _defaultPanelWidth = 380.0;

  final nowPlayingPanelWidth = _defaultPanelWidth.obs;
  final isNowPlayingPanelVisible = true.obs;

  void setUseBottomNav(bool value) {
    if (useBottomNav.value != value) {
      useBottomNav.value = value;
    }
  }

  void setOverlayContext(BuildContext? context) {
    overlayContext = context;
  }

  BuildContext? get overlayContextOrFallback => overlayContext ?? Get.context;

  void setNowPlayingPanelWidth(double width) {
    final clamped = width.clamp(_minPanelWidth, _maxPanelWidth);
    if (nowPlayingPanelWidth.value != clamped) {
      nowPlayingPanelWidth.value = clamped;
      Hive.box("AppPrefs").put("nowPlayingPanelWidth", clamped);
    }
  }

  void toggleNowPlayingPanel() {
    isNowPlayingPanelVisible.value = !isNowPlayingPanelVisible.value;
    Hive.box("AppPrefs").put("isNowPlayingPanelVisible", isNowPlayingPanelVisible.value);
  }

  @override
  void onInit() {
    super.onInit();
    final box = Hive.box("AppPrefs");
    final savedWidth = box.get("nowPlayingPanelWidth");
    if (savedWidth is double) {
      nowPlayingPanelWidth.value = savedWidth.clamp(_minPanelWidth, _maxPanelWidth);
    } else if (savedWidth is int) {
      nowPlayingPanelWidth.value = savedWidth.toDouble().clamp(_minPanelWidth, _maxPanelWidth);
    }
    final savedVisible = box.get("isNowPlayingPanelVisible");
    if (savedVisible is bool) {
      isNowPlayingPanelVisible.value = savedVisible;
    }
  }
}
