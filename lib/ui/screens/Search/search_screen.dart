import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import 'components/search_item.dart';
import '/ui/constants/layout.dart';
import '/ui/shell_controller.dart';
import '../../widgets/modified_text_field.dart';
import '/ui/navigator.dart';
import 'search_screen_controller.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchScreenController = Get.find<SearchScreenController>();
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;
    final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingSearch;
    final horizontalPadding =
        useBottomNav ? kContentLeftPaddingWithBottomNav : kContentLeftPaddingWithoutBottomNav;
    final listBottomPadding =
        useBottomNav ? kContentBottomPaddingWithBottomNav : kContentBottomPaddingWithPlayer;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(top: topPadding, left: horizontalPadding, right: horizontalPadding),
        child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.search,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ModifiedTextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: searchScreenController.textInputController,
                      textInputAction: TextInputAction.search,
                      onChanged: searchScreenController.onChanged,
                      onSubmitted: (val) {
                        if (val.contains("https://")) {
                          searchScreenController.filterLinks(Uri.parse(val));
                          searchScreenController.reset();
                          return;
                        }
                        ScreenNavigationSetup.pushContentRoute(
                            ScreenNavigationSetup.searchResultScreen,
                            arguments: val);
                        searchScreenController.addToHistryQueryList(val);
                      },
                      autofocus: !useBottomNav,
                      cursorColor: Theme.of(context).textTheme.bodySmall!.color,
                      decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 5),
                          hintText: context.l10n.searchDes,
                          suffix: IconButton(
                            onPressed: searchScreenController.reset,
                            icon: const Icon(Icons.close),
                            splashRadius: 16,
                            iconSize: 19,
                          )),
                    ),
                    Expanded(
                      child: Obx(() {
                        final isEmpty = searchScreenController
                                .suggestionList.isEmpty ||
                            searchScreenController.textInputController.text ==
                                "";
                        final list = isEmpty
                            ? searchScreenController.historyQuerylist.toList()
                            : searchScreenController.suggestionList.toList();
                        return ListView(
                            padding: EdgeInsets.only(top: 5, bottom: listBottomPadding),
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            children: searchScreenController.urlPasted.isTrue
                                ? [
                                    InkWell(
                                      onTap: () {
                                        searchScreenController.filterLinks(
                                            Uri.parse(searchScreenController
                                                .textInputController.text));
                                        searchScreenController.reset();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10.0),
                                        child: SizedBox(
                                          width: double.maxFinite,
                                          height: 60,
                                          child: Center(
                                              child: Text(
                                            context.l10n.urlSearchDes,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          )),
                                        ),
                                      ),
                                    )
                                  ]
                                : list
                                    .map((item) => SearchItem(
                                        queryString: item,
                                        isHistoryString: isEmpty))
                                    .toList());
                      }),
                    )
                  ],
                ),
    ));
  }
}
