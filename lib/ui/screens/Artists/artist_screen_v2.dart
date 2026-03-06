import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/screens/Artists/artist_header.dart';
import '../../navigator.dart';
import '../../widgets/loader.dart';
import '../../widgets/separate_tab_item_widget.dart';
import 'artist_screen_controller.dart';

class ArtistScreenBN extends StatelessWidget {
  const ArtistScreenBN(
      {super.key, required this.artistScreenController, required this.tag});
  final ArtistScreenController artistScreenController;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final c = artistScreenController.tabController;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              ScreenNavigationSetup.popContent();
            },
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: Obx(
            () => artistScreenController.isArtistContentFetced.isTrue
                ? Text(artistScreenController.artist_.name,
                    style: Theme.of(context).textTheme.titleLarge)
                : const SizedBox.shrink(),
          ),
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Theme.of(context).canvasColor,
        leading: IconButton(
          onPressed: () {
            Get.nestedKey(ScreenNavigationSetup.contentId)!.currentState!.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        elevation: 0,
        title: Obx(
          () => artistScreenController.isArtistContentFetced.isTrue
              ? Text(
                  artistScreenController.artist_.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtistHeader(controller: artistScreenController),
          TabBar(
            controller: c,
            onTap: artistScreenController.onDestinationSelected,
            splashFactory: NoSplash.splashFactory,
            isScrollable: true,
            tabs: [context.l10n.songs, context.l10n.videos, context.l10n.albums, context.l10n.singles]
                .map((e) => Tab(text: e))
                .toList(),
          ),
          Expanded(
            child: Obx(
              () => TabBarView(
                controller: c,
                children: artistScreenController.isArtistContentFetced.isFalse
                    ? List.generate(
                        4,
                        (_) => const Center(child: LoadingIndicator()),
                      )
                    : [
                        _TabContent(controller: artistScreenController, tag: tag, tabIndex: 0),
                        _TabContent(controller: artistScreenController, tag: tag, tabIndex: 1),
                        _TabContent(controller: artistScreenController, tag: tag, tabIndex: 2),
                        _TabContent(controller: artistScreenController, tag: tag, tabIndex: 3),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.controller,
    required this.tag,
    required this.tabIndex,
  });
  final ArtistScreenController controller;
  final String tag;
  final int tabIndex;

  static const _tabNames = ["Songs", "Videos", "Albums", "Singles"];

  @override
  Widget build(BuildContext context) {
    final currentTabName = _tabNames[tabIndex];
    return Obx(() {
      final isSelected = controller.navigationRailCurrentIndex.value == tabIndex;
      final hasContent = controller.sepataredContent.containsKey(currentTabName);
      if (isSelected && !hasContent) {
        return const Center(child: LoadingIndicator());
      }
      if (!hasContent) {
        return const Center(child: SizedBox.shrink());
      }
      return Padding(
        padding: const EdgeInsets.only(left: 15, right: 15),
        child: SeparateTabItemWidget(
          artistControllerTag: tag,
          hideTitle: true,
          isResultWidget: false,
          items: controller.sepataredContent[currentTabName]['results'],
          title: currentTabName,
          scrollController: currentTabName == "Songs"
              ? controller.songScrollController
              : currentTabName == "Videos"
                  ? controller.videoScrollController
                  : currentTabName == "Albums"
                      ? controller.albumScrollController
                      : currentTabName == "Singles"
                          ? controller.singlesScrollController
                          : null,
        ),
      );
    });
  }
}
