import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/constants/layout.dart';
import '/ui/screens/Search/search_result_screen_v2.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../../navigator.dart';
import '../../widgets/adaptive_tab_screen.dart';
import '../../widgets/animated_screen_transition.dart';
import '../../widgets/loader.dart';
import '../../widgets/search_related_widgets.dart';
import '../../widgets/separate_tab_item_widget.dart';
import 'search_result_screen_controller.dart';

class SearchResultScreen extends StatelessWidget {
  const SearchResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tag = key.hashCode.toString();
    final searchResScrController =
        (Get.isRegistered<SearchResultScreenController>(tag: tag))
            ? Get.find<SearchResultScreenController>(tag: tag)
            : Get.put(SearchResultScreenController(), tag: tag);
    return AdaptiveTabScreen(
      narrowChild: SearchResultScreenBN(
        searchResScrController: searchResScrController,
      ),
      wideChild: Scaffold(
            body: Row(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: IntrinsicHeight(
                      child: Obx(
                        () => NavigationRail(
                          onDestinationSelected:
                              searchResScrController.onDestinationSelected,
                          minWidth: 60,
                          destinations: (searchResScrController
                                      .isResultContentFetced.value &&
                                  searchResScrController.railItems.isNotEmpty)
                              ? [
                                  railDestination(context, context.l10n.results),
                                  ...(searchResScrController.railItems.map(
                                      (element) => railDestination(context, element))),
                                ]
                              : [
                                  railDestination(context, context.l10n.results),
                                  railDestination(context, "")
                                ],
                          leading: Column(
                            children: [
                              SizedBox(
                                height: context.isLandscape ? 20 : 45,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .color,
                                ),
                                onPressed: () {
                                  ScreenNavigationSetup.popContent();
                                },
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                          labelType: NavigationRailLabelType.all,
                          selectedIndex: searchResScrController
                              .navigationRailCurrentIndex.value,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(
                    () {
                      final settings = Get.find<SettingsScreenController>();
                      final factor = settings.animationSpeedFactor;
                      final enabled = factor > 0;
                      const baseMs = 380;
                      final effectiveMs =
                          (baseMs * (factor == 0 ? 1.0 : factor)).round();
                      return AnimatedScreenTransition(
                        enabled: enabled,
                        resverse: searchResScrController.isTabTransitionReversed,
                        duration: Duration(milliseconds: effectiveMs),
                        child: SizedBox.expand(
                          key: ValueKey<int>(
                            searchResScrController
                                    .navigationRailCurrentIndex
                                    .toInt() *
                                8,
                          ),
                          child: Body(
                            searchResScrController: searchResScrController,
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
    );
  }

  NavigationRailDestination railDestination(BuildContext context, String label) {
    return NavigationRailDestination(
      icon: const SizedBox.shrink(),
      label: RotatedBox(
          quarterTurns: -1,
          child: Text(context.trKey(label))),
    );
  }
}

class Body extends StatelessWidget {
  const Body({
    super.key,
    required this.searchResScrController,
  });

  final SearchResultScreenController searchResScrController;

  @override
  Widget build(BuildContext context) {
    if (searchResScrController.navigationRailCurrentIndex.value == 0) {
      return Obx(() {
        if (searchResScrController.isResultContentFetced.isTrue &&
            searchResScrController.railItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.l10n.nomatch,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text("'${searchResScrController.queryString.value}'"),
              ],
            ),
          );
        } else if (searchResScrController.isResultContentFetced.isTrue) {
          return ResultWidget(searchResScrController: searchResScrController);
        } else {
          return const Center(
            child: LoadingIndicator(),
          );
        }
      });
    } else {
      if (searchResScrController.isResultContentFetced.isTrue) {
        final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingSearch;
        final name = searchResScrController.railItems[
            searchResScrController.navigationRailCurrentIndex.value - 1];
        return SeparateTabItemWidget(
          items: const [],
          title: name,
          topPadding: topPadding,
          scrollController: searchResScrController.scrollControllers[name],
          searchResultController: searchResScrController,
        );
      }
    }
    return const SizedBox.shrink();
  }
}
