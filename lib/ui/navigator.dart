import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_shell.dart';

class ScreenNavigationSetup {
  ScreenNavigationSetup._();

  /// Route ownership model:
  /// - Content routes (`home/search/artist/album/playlist`) belong to the
  ///   nested content navigator identified by [contentId].
  /// - Global overlays (dialogs/bottom sheets/loaders) belong to the app/root
  ///   navigator and should be dismissed via [popOverlayIfOpen] to avoid
  ///   accidentally popping content routes.
  static const id = 1;
  static const contentId = 2;
  static const homeScreen = '/homeScreen';
  static const searchScreen = '/searchScreen';
  static const searchResultScreen = '/searchResultScreen';
  static const artistScreen = '/artistScreen';
  static const albumScreen = '/albumScreen';
  static const playlistScreen = '/playlistScreen';

  static GlobalKey<NavigatorState>? get contentNavigatorKey =>
      Get.nestedKey(contentId);

  static NavigatorState? get contentState => contentNavigatorKey?.currentState;

  static Future<T?> pushContentRoute<T>(String name, {Object? arguments}) =>
      Get.toNamed<T>(name, id: contentId, arguments: arguments) ??
      Future.value(null);

  static void popContent<T>([T? result]) => contentState?.pop(result);

  static bool get canPopContent => contentState?.canPop() ?? false;

  static Future<T?> offContentRoute<T>(String name, {Object? arguments}) =>
      Get.offNamed<T>(name, id: contentId, arguments: arguments) ??
      Future.value(null);

  static bool get isOverlayOpen => Get.isDialogOpen ?? false;

  static void popOverlayIfOpen<T>([T? result]) {
    if (!isOverlayOpen) return;
    Get.back<T>(result: result);
  }
}

class ScreenNavigation extends StatelessWidget {
  const ScreenNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Get.nestedKey(ScreenNavigationSetup.id),
      initialRoute: '/shell',
      onGenerateRoute: (settings) {
        if (settings.name == '/shell') {
          return GetPageRoute(page: () => const AppShell(), settings: settings);
        }
        return null;
      },
    );
  }
}
