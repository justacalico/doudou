import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/screens/Artists/artist_header.dart';
import '/ui/screens/Artists/artist_screen_v2.dart';

export 'about_artist.dart' show AboutArtist;
import '../../navigator.dart';
import '../../widgets/adaptive_tab_screen.dart';
import '../../widgets/loader.dart';
import '../../widgets/separate_tab_item_widget.dart';
import 'artist_screen_controller.dart';
import '../Library/library_controller.dart';

class ArtistScreen extends StatelessWidget {
  const ArtistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tag = key.hashCode.toString();
    final artistScreenController =
        Get.isRegistered<ArtistScreenController>(tag: tag)
            ? Get.find<ArtistScreenController>(tag: tag)
            : Get.put(ArtistScreenController(), tag: tag);
    return Scaffold(
      body: AdaptiveTabScreen(
        narrowChild: ArtistScreenBN(
            artistScreenController: artistScreenController, tag: tag),
        wideChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8, right: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                        ),
                        onPressed: () {
                          ScreenNavigationSetup.popContent();
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(
                          () => artistScreenController.isArtistContentFetced.isTrue
                              ? Text(
                                  artistScreenController.artist_.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                ArtistHeader(controller: artistScreenController),
                Expanded(
                  child: Obx(() {
                    final c = artistScreenController.tabController;
                    if (c == null) return const Center(child: SizedBox.shrink());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          controller: c,
                          onTap: artistScreenController.onDestinationSelected,
                          tabs: [
                            context.l10n.songs,
                            context.l10n.videos,
                            context.l10n.albums,
                            context.l10n.singles
                          ].map((e) => Tab(text: e)).toList(),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: c,
                            children: [
                              _TabBody(tag: tag, tabIndex: 0),
                              _TabBody(tag: tag, tabIndex: 1),
                              _TabBody(tag: tag, tabIndex: 2),
                              _TabBody(tag: tag, tabIndex: 3),
                            ],
                          ),
                        ),
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

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tag, required this.tabIndex});
  final String tag;
  final int tabIndex;

  static const _tabNames = ["Songs", "Videos", "Albums", "Singles"];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ArtistScreenController>(tag: tag);
    final currentTabName = _tabNames[tabIndex];
    return Obx(() {
      final isSelected = controller.navigationRailCurrentIndex.value == tabIndex;
      final hasContent = controller.sepataredContent.containsKey(currentTabName);

      if (isSelected && !hasContent) {
        // Proactively trigger load for the initially selected tab when content
        // hasn't been separated yet (common on non‑YouTube backends).
        if (currentTabName == "Songs") {
          controller.ensureSongsLoaded();
        } else {
          controller.onDestinationSelected(tabIndex);
        }
        return const Center(child: LoadingIndicator());
      }

      if (!hasContent) {
        return const Center(child: SizedBox.shrink());
      }

      final items = controller.sepataredContent[currentTabName]['results'];

      Widget body = SeparateTabItemWidget(
        artistControllerTag: tag,
        isResultWidget: false,
        items: items,
        title: currentTabName,
        topPadding: 8,
        scrollController: currentTabName == "Songs"
            ? controller.songScrollController
            : currentTabName == "Videos"
                ? controller.videoScrollController
                : currentTabName == "Albums"
                    ? controller.albumScrollController
                    : currentTabName == "Singles"
                        ? controller.singlesScrollController
                        : null,
      );

      if (currentTabName == "Songs" &&
          items is List &&
          items.isEmpty &&
          Get.isRegistered<LibrarySongsController>() &&
          !Get.find<LibrarySongsController>().isSongFetched.value) {
        body = Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Loading your library in background...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      }

      return body;
    });
  }
}
