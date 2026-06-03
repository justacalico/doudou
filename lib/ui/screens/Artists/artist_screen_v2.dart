import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/ui/models/content_category.dart';

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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: ArtistHeader(controller: artistScreenController),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: c,
              tabs: ContentCategoryMapper.artistTabs
                  .map((category) => Tab(text: category.localizedLabel(context)))
                  .toList(),
              onTap: artistScreenController.onDestinationSelected,
            ),
          ),
        ],
        body: Obx(
          () => TabBarView(
            controller: c,
            children: artistScreenController.isArtistContentFetced.isFalse
                ? List.generate(
                    4,
                    (_) => const Center(child: LoadingIndicator()),
                  )
                : [
                    _TabContent(
                        controller: artistScreenController,
                        tag: tag,
                        tabIndex: 0),
                    _TabContent(
                        controller: artistScreenController,
                        tag: tag,
                        tabIndex: 1),
                    _TabContent(
                        controller: artistScreenController,
                        tag: tag,
                        tabIndex: 2),
                    _TabContent(
                        controller: artistScreenController,
                        tag: tag,
                        tabIndex: 3),
                  ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final currentTabCategory = ContentCategoryMapper.artistTabs[tabIndex];
    final currentTabName = currentTabCategory.canonicalKey;
    return Obx(() {
      final isSelected =
          controller.navigationRailCurrentIndex.value == tabIndex;
      final hasContent =
          controller.sepataredContent.containsKey(currentTabName);
      if (isSelected && !hasContent) {
        return const Center(child: LoadingIndicator());
      }
      if (!hasContent) {
        return const Center(child: SizedBox.shrink());
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent / 2) {
              controller.tryLoadMore(currentTabName);
            }
          }
          return false;
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15),
          child: SeparateTabItemWidget(
            artistControllerTag: tag,
            hideTitle: true,
            isResultWidget: false,
            items: controller.sepataredContent[currentTabName]['results'],
            title: currentTabName,
          ),
        ),
      );
    });
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final List<Tab> tabs;
  final ValueChanged<int> onTap;

  _TabBarDelegate({
    required this.tabController,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).canvasColor,
      child: TabBar(
        controller: tabController,
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        isScrollable: true,
        tabs: tabs,
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.tabController != tabController ||
        oldDelegate.tabs != tabs ||
        oldDelegate.onTap != onTap;
  }
}
