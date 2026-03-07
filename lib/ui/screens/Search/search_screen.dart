import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import 'components/search_item.dart';
import '/ui/constants/doudou_design.dart';
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
    final theme = Theme.of(context);
    const topPadding = 24.0;
    final horizontalPadding =
        useBottomNav ? kContentLeftPaddingWithBottomNav : kContentLeftPaddingWithoutBottomNav;
    final listBottomPadding =
        useBottomNav ? kContentBottomPaddingWithBottomNav : kContentBottomPaddingWithPlayer;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(
            top: topPadding, left: horizontalPadding, right: kContentRightPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.search,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: kDoudouPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: kDoudouSurfaceHover,
                borderRadius: BorderRadius.circular(kDoudouRadiusCard),
                border: Border.all(color: kDoudouBorder, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ModifiedTextField(
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
                cursorColor: theme.textTheme.bodySmall!.color,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: context.l10n.searchDes,
                  hintStyle: const TextStyle(color: kDoudouZinc500, fontSize: 14),
                  suffix: IconButton(
                    onPressed: searchScreenController.reset,
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    splashRadius: 16,
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final isEmpty = searchScreenController.suggestionList.isEmpty ||
                    searchScreenController.textInputController.text == "";
                final list = isEmpty
                    ? searchScreenController.historyQuerylist.toList()
                    : searchScreenController.suggestionList.toList();
                final urlPasted = searchScreenController.urlPasted.isTrue;

                if (urlPasted) {
                  return ListView(
                    padding: EdgeInsets.only(bottom: listBottomPadding),
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    children: [
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(kDoudouRadiusCard),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kDoudouRadiusCard),
                          onTap: () {
                            searchScreenController.filterLinks(Uri.parse(
                                searchScreenController.textInputController.text));
                            searchScreenController.reset();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: kDoudouSurface,
                              borderRadius:
                                  BorderRadius.circular(kDoudouRadiusCard),
                              border: Border.all(
                                  color: kDoudouBorderStrong, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                context.l10n.urlSearchDes,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (list.isEmpty) {
                  return ListView(
                    padding: EdgeInsets.only(bottom: listBottomPadding),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.l10n.searchDes,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kDoudouZinc500,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final sectionLabel = isEmpty ? "Recent" : "Suggestions";
                return ListView(
                  padding: EdgeInsets.only(top: 8, bottom: listBottomPadding),
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        sectionLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: kDoudouZinc500,
                        ),
                      ),
                    ),
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      SearchItem(
                        queryString: list[i],
                        isHistoryString: isEmpty,
                      ),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
