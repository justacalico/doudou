import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'search_item.dart';
import '/ui/screens/Home/home_screen_controller.dart';
import '/ui/screens/Search/search_screen_controller.dart';

import '../../../navigator.dart';

class DesktopSearchBar extends StatefulWidget {
  const DesktopSearchBar({super.key});

  @override
  State<DesktopSearchBar> createState() => _DesktopSearchBarState();
}

class _DesktopSearchBarState extends State<DesktopSearchBar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final search = Get.find<SearchScreenController>();
    _focusNode.addListener(() {
      search.setDesktopSearchFocus(_focusNode.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchScreenController = Get.find<SearchScreenController>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.space):
                const DoNothingAndStopPropagationTextIntent()
          },
          child: SearchBar(
                controller: searchScreenController.textInputController,
                onTap: () {
                  if (!_focusNode.hasFocus) {
                    _focusNode.requestFocus();
                  }
                },
                onTapOutside: (event) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _focusNode.unfocus();
                  });
                },
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
                  _focusNode.unfocus();
                },
                focusNode: _focusNode,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return kDoudouSurfaceHover;
                  }
                  return kDoudouSurface;
                }),
                hintText: context.l10n.searchDes,
                leading: IconButton(
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    if (_focusNode.hasFocus) {
                      _focusNode.unfocus();
                    }
                  },
                  icon: Obx(() => Icon(
                    searchScreenController.isSearchBarInFocus.isTrue
                        ? Icons.arrow_back
                        : Icons.search,
                    color: searchScreenController.isSearchBarInFocus.isTrue
                        ? kDoudouPurpleLight
                        : kDoudouZinc500,
                    size: 18,
                  )),
                ),
                trailing: [
                  IconButton(
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.l10n.shuffleAll,
                    icon: const Icon(Icons.shuffle, size: 18),
                    onPressed: () {
                      final c = Get.find<HomeScreenController>();
                      c.shuffleAll(
                        emptyMessage: context.l10n.noSongsInLibrary,
                        playFromName: context.l10n.shuffleAll,
                      );
                    },
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.l10n.favorites,
                    icon: const Icon(Icons.favorite_border, size: 18),
                    onPressed: () {
                      final c = Get.find<HomeScreenController>();
                      c.shuffleFavorites(
                        emptyMessage: context.l10n.favoritesEmpty,
                        playFromName: context.l10n.favorites,
                      );
                    },
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.l10n.downloads,
                    icon: const Icon(Icons.download, size: 18),
                    onPressed: () {
                      final c = Get.find<HomeScreenController>();
                      c.shuffleDownloads(
                        emptyMessage: context.l10n.noOfflineSong,
                        playFromName: context.l10n.downloads,
                      );
                    },
                  ),
                  Obx(() => searchScreenController.isSearchBarInFocus.isTrue
                      ? IconButton(
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: searchScreenController.reset,
                          icon: const Icon(Icons.clear, size: 18))
                      : const SizedBox.shrink())
                ],
                padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return BorderSide(
                        color: kDoudouPurple.withValues(alpha: 0.5), width: 1);
                  }
                  return BorderSide(color: kDoudouBorderStrong, width: 1);
                }),
                shape: WidgetStatePropertyAll<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Container(
              decoration: BoxDecoration(
                  color: kDoudouSurface,
                  border: Border.all(color: kDoudouBorderStrong, width: 1),
                  borderRadius: BorderRadius.circular(kDoudouRadiusCard)),
              constraints: const BoxConstraints(minHeight: 0, maxHeight: 300),
              child: Obx(() {
                final isHistoryString =
                    searchScreenController.textInputController.text.isEmpty &&
                        searchScreenController.suggestionList.isEmpty;
                final listToShow = isHistoryString
                    ? searchScreenController.historyQuerylist
                    : searchScreenController.suggestionList;
                return searchScreenController.urlPasted.isTrue
                    ? InkWell(
                        onTap: () {
                          searchScreenController.filterLinks(Uri.parse(
                              searchScreenController.textInputController.text));
                          searchScreenController.reset();
                        },
                        child: SizedBox(
                          width: double.maxFinite,
                          height: 50,
                          child: Center(
                              child: Text(
                            context.l10n.urlSearchDes,
                            style: Theme.of(context).textTheme.titleMedium,
                          )),
                        ),
                      )
                    : searchScreenController.isSearchBarInFocus.isTrue &&
                            listToShow.isNotEmpty
                        ? ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(5.0),
                            children: listToShow.map((item) {
                              return SearchItem(
                                  queryString: item,
                                  isHistoryString: isHistoryString);
                            }).toList())
                        : const SizedBox.shrink();
              }),
            ))
      ],
    );
  }
}
