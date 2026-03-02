import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shell_controller.dart';

/// Chooses [narrowChild] when using bottom nav or desktop, [wideChild] otherwise.
class AdaptiveTabScreen extends StatelessWidget {
  const AdaptiveTabScreen({
    super.key,
    required this.narrowChild,
    required this.wideChild,
  });

  final Widget narrowChild;
  final Widget wideChild;

  static bool get useNarrowLayout {
    if (!Get.isRegistered<ShellController>()) return true;
    return GetPlatform.isDesktop ||
        Get.find<ShellController>().useBottomNav.value;
  }

  @override
  Widget build(BuildContext context) {
    return useNarrowLayout ? narrowChild : wideChild;
  }
}
