import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'search_item.dart';
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
    final theme = Theme.of(context);
    final searchSurface = theme.colorScheme.surfaceContainerHighest;
    final searchDropdownSurface = theme.colorScheme.surfaceContainer;
    final searchBorder = theme.colorScheme.outline;
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
            backgroundColor: WidgetStatePropertyAll<Color>(searchSurface),
            hintText: context.l10n.searchDes,
            leading: IconButton(
                onPressed: () {
                  if (_focusNode.hasFocus) {
                    _focusNode.unfocus();
                  }
                },
                icon: Obx(() => Icon(
                    searchScreenController.isSearchBarInFocus.isTrue
                        ? Icons.arrow_back
                        : Icons.search))),
            trailing: [
              Obx(() => searchScreenController.isSearchBarInFocus.isTrue
                  ? IconButton(
                      onPressed: searchScreenController.reset,
                      icon: const Icon(Icons.clear))
                  : const SizedBox.shrink())
            ],
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.only(left: 15, right: 15)),
            side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: searchBorder, width: 1),
            ),
          ),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Container(
              decoration: BoxDecoration(
                  color: searchDropdownSurface,
                  border: Border.all(color: searchBorder, width: 1),
                  borderRadius: BorderRadius.circular(20)),
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
