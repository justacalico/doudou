import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/widgets/modification_list.dart';

import '../screens/Artists/artist_screen_controller.dart';
import '../screens/Artists/artist_songs_table.dart';
import '../screens/Search/search_result_screen_controller.dart';
import 'list_widget.dart';
import 'loader.dart';
import 'sort_widget.dart';

class SeparateTabItemWidget extends StatelessWidget {
  const SeparateTabItemWidget(
      {super.key,
      required this.items,
      required this.title,
      this.isCompleteList = true,
      this.isResultWidget = true,
      this.hideTitle = false,
      this.topPadding = 0,
      this.scrollController,
      this.artistControllerTag,
      this.searchResultController});

  /// tag for accessing Artist controller inst, [artistControllerTag] only valid for Artist screen
  final String? artistControllerTag;
  final List<dynamic> items;
  final String title;
  final bool isCompleteList;
  final double topPadding;
  final bool isResultWidget;
  final bool hideTitle;
  final ScrollController? scrollController;
  final SearchResultScreenController? searchResultController;

  @override
  Widget build(BuildContext context) {
    final artistController =
        Get.isRegistered<ArtistScreenController>(tag: artistControllerTag)
            ? Get.find<ArtistScreenController>(tag: artistControllerTag)
            : null;
    final searchResController = searchResultController;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasUnboundedHeight =
            constraints.maxHeight == double.infinity;
        return Padding(
          padding: EdgeInsets.only(top: topPadding, left: 5),
          child: Column(
            mainAxisSize: hasUnboundedHeight
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              if (!hideTitle)
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.trKey(title),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      isCompleteList
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: () {
                                searchResController!.viewAllCallback(title);
                              },
                              child: Text(context.l10n.viewAll,
                                  style:
                                      Theme.of(Get.context!).textTheme.titleSmall))
                    ],
                  ),
                ),
              isCompleteList
                  ? Obx(() => SortWidget(
                        tag: "${title}_$artistControllerTag",
                        screenController: artistController,
                        isAdditionalOperationRequired: artistController != null &&
                            (title == "Songs" || title == "Videos"),
                        isSearchFeatureRequired: artistController != null,
                        titleLeftPadding: 9,
                        itemCountTitle:
                            "${isResultWidget ? (searchResController?.separatedResultContent[title] ?? []).length : (artistController?.sepataredContent[title] != null ? artistController?.sepataredContent[title]['results'] : []).length} ${context.l10n.items}",
                        requiredSortTypes: buildSortTypeSet(
                            title == 'Albums' || title == "Singles",
                            title == "Songs" || title == "Videos"),
                        onSort: (type, ascending) {
                          isResultWidget
                              ? searchResController!.onSort(type, ascending, title)
                              : artistController?.onSort(type, ascending, title);
                        },
                        onSearch: artistController?.onSearch,
                        onSearchClose: artistController?.onSearchClose,
                        onSearchStart: artistController?.onSearchStart,
                        startAdditionalOperation:
                            artistController?.startAdditionalOperation,
                        selectAll: artistController?.selectAll,
                        performAdditionalOperation:
                            artistController?.performAdditionalOperation,
                        cancelAdditionalOperation:
                            artistController?.cancelAdditionalOperation,
                      ))
                  : const SizedBox.shrink(),
              _wrapListChild(
                hasUnboundedHeight: hasUnboundedHeight,
                isCompleteList: isCompleteList,
                isResultWidget: isResultWidget,
                artistController: artistController,
                searchResController: searchResController,
                title: title,
                items: items,
                scrollController: scrollController,
                artistControllerTag: artistControllerTag,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wrapListChild({
    required bool hasUnboundedHeight,
    required bool isCompleteList,
    required bool isResultWidget,
    required String title,
    required List<dynamic> items,
    ArtistScreenController? artistController,
    SearchResultScreenController? searchResController,
    ScrollController? scrollController,
    String? artistControllerTag,
  }) {
    Widget child;
    if (isCompleteList) {
      if (isResultWidget) {
        child = Obx(() {
          if (searchResController != null &&
              searchResController.isSeparatedResultContentFetced.isTrue) {
            return ListWidget(
              searchResController.separatedResultContent[title],
              title,
              isCompleteList,
              scrollController: scrollController,
            );
          } else {
            return const Center(child: LoadingIndicator());
          }
        });
      } else {
        if (artistController != null &&
            artistController.isArtistContentFetced.isTrue) {
          child = Obx(() {
            final useTable = title == "Songs" &&
                artistController.additionalOperationMode.value ==
                    OperationMode.none &&
                MediaQuery.of(Get.context!).size.width >= 600;
            return artistController.additionalOperationMode.value ==
                    OperationMode.none
                ? useTable
                    ? ArtistSongsTable(
                        items: items,
                        artistName: artistController.artist_.name,
                        controllerTag: artistControllerTag!,
                        scrollController: scrollController,
                      )
                    : ListWidget(
                        items,
                        title,
                        isCompleteList,
                        isArtistSongs: true,
                        artist: artistController.artist_,
                        scrollController: scrollController,
                      )
                : ModificationList(
                    mode: artistController.additionalOperationMode.value,
                    screenController: artistController,
                  );
          });
        } else {
          child = const Center(child: LoadingIndicator());
        }
      }
    } else {
      child = ListWidget(
        items,
        title,
        isCompleteList,
        scrollController: scrollController,
      );
    }
    if (hasUnboundedHeight) {
      return child;
    }
    return Expanded(child: child);
  }
}
