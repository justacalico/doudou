import 'package:buttons_tabbar/buttons_tabbar.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/widgets/loader.dart';
import 'package:doudou/ui/widgets/search_related_widgets.dart';
import '/ui/models/content_category.dart';

import '../../navigator.dart';
import '../../widgets/separate_tab_item_widget.dart';
import 'components/search_query_bar.dart';
import 'search_result_screen_controller.dart';
import '/ui/design/doudou_colors.dart';

class SearchResultScreenBN extends StatelessWidget {
  const SearchResultScreenBN({
    super.key,
    required this.searchResScrController,
  });

  final SearchResultScreenController searchResScrController;

  @override
  Widget build(BuildContext context) {
    final topPadding = context.isLandscape ? 50.0 : 80.0;
    return Scaffold(
      body: Padding(
          padding: EdgeInsets.only(
            top: topPadding,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          ScreenNavigationSetup.popContent();
                        },
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                    ),
                  ),
                  Expanded(
                      child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.searchRes,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child:
                              SearchQueryBar(controller: searchResScrController),
                        ),
                      ),
                    ),
                  ]))
                ],
              ),
              Expanded(
                child: Obx(
                  () {
                    if (searchResScrController.isResultContentFetched.isTrue &&
                        searchResScrController.resultContent.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.nomatch,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                                "'${searchResScrController.queryString.value}'"),
                          ],
                        ),
                      );
                    } else if (searchResScrController
                        .isResultContentFetched.isTrue) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(left: 15.0, top: 10),
                            child: DefaultTabController(
                              length: searchResScrController
                                      .railItems.length +
                                  1,
                              child: ButtonsTabBar(
                              onTap:
                                  searchResScrController.onDestinationSelected,

                              controller: searchResScrController.tabController,
                              contentPadding:
                                  const EdgeInsets.only(left: 15, right: 15),
                              backgroundColor: context
                                  .doudouColors.accentPrimary,
                              unselectedBackgroundColor: context
                                  .doudouColors.surfaceElevated,
                              borderWidth: 0,
                              buttonMargin: const EdgeInsets.only(
                                  right: 10, left: 4, top: 4, bottom: 4),
                              borderColor: Colors.black,
                              labelStyle: TextStyle(
                                color: context.doudouColors.onAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              unselectedLabelStyle: TextStyle(
                                color: context.doudouColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              // Add your tabs here
                              tabs: [
                                Tab(text: context.l10n.results),
                                ...searchResScrController.railItems
                                    .map((item) => Tab(
                                          text: ContentCategoryMapper.fromKey(
                                                  item)
                                              .localizedLabel(context),
                                        ))
                              ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                              child: TabBarView(
                                controller:
                                    searchResScrController.tabController,
                                children: [
                                  ResultWidget(
                                    isv2Used: true,
                                    searchResScrController:
                                        searchResScrController,
                                  ),
                                  ...searchResScrController.railItems
                                      .map((tabName) {
                                    final category =
                                        ContentCategoryMapper.fromKey(tabName);
                                    if (category.isSongLike) {
                                      return SeparateTabItemWidget(
                                        isResultWidget: true,
                                        hideTitle: true,
                                        items: const [],
                                        title: tabName,
                                        isCompleteList: true,
                                        scrollController: searchResScrController
                                            .scrollControllers[tabName],
                                        searchResultController:
                                            searchResScrController,
                                      );
                                    } else {
                                      return SeparateTabItemWidget(
                                        title: tabName,
                                        hideTitle: true,
                                        items: const [],
                                        scrollController: searchResScrController
                                            .scrollControllers[tabName],
                                        searchResultController:
                                            searchResScrController,
                                      );
                                    }
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return const Center(
                        child: LoadingIndicator(),
                      );
                    }
                  },
                ),
              )
            ],
          )),
    );
  }
}
