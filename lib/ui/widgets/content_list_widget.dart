import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '../navigator.dart';
import '../screens/Search/search_result_screen_controller.dart';
import '/models/artist.dart';
import '/ui/widgets/content_list_widget_item.dart';
import '/ui/widgets/image_widget.dart';

class ContentListWidget extends StatelessWidget {
  ///ContentListWidget is used to render a section of Content like a list of Albums or Playlists in HomeScreen
  const ContentListWidget(
      {super.key,
      this.content,
      this.isHomeContent = true,
      this.scrollController});

  ///content will be of class Type AlbumContent, PlaylistContent, or ArtistContent
  final dynamic content;
  final bool isHomeContent;
  final ScrollController? scrollController;

  int get _itemCount {
    final type = content.runtimeType.toString();
    if (type == "AlbumContent") return content.albumList.length;
    if (type == "ArtistContent") return content.content.length;
    return content.playlistList.length;
  }

  @override
  Widget build(BuildContext context) {
    final type = content.runtimeType.toString();
    final isAlbumContent = type == "AlbumContent";
    final isArtistContent = type == "ArtistContent";
    final title = content.title;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  !isHomeContent && title.length > 12
                      ? "${title.substring(0, 12)}..."
                      : title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                !isHomeContent
                    ? TextButton(
                        onPressed: () {
                          final scrresController =
                              Get.find<SearchResultScreenController>();
                          scrresController.viewAllCallback(title);
                        },
                        child: Text(context.l10n.viewAll,
                            style: Theme.of(Get.context!).textTheme.titleSmall))
                    : const SizedBox.shrink()
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 200,
            child: Scrollbar(
              thickness: GetPlatform.isDesktop ? null : 0,
              controller: scrollController,
              child: ListView.separated(
                  controller: scrollController,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (context, index) => const SizedBox(
                        width: 15,
                      ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _itemCount,
                  itemBuilder: (_, index) {
                    if (isArtistContent) {
                      final artist = content.content[index] as Artist;
                      return InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          ScreenNavigationSetup.pushContentRoute(
                              ScreenNavigationSetup.artistScreen,
                              arguments: [false, artist]);
                        },
                        child: Container(
                          width: 130,
                          height: 180,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ImageWidget(size: 120, artist: artist),
                              const SizedBox(height: 6),
                              Text(
                                artist.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (isAlbumContent) {
                      return ContentListItem(content: content.albumList[index]);
                    }
                    return ContentListItem(
                        content: content.playlistList[index]);
                  }),
            ),
          ),
        ],
      );
  }
}
