import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '../navigator.dart';
import '/models/artist.dart';
import '/ui/widgets/content_list_widget_item.dart';
import '/ui/widgets/image_widget.dart';

class ContentListWidget extends StatelessWidget {
  const ContentListWidget(
      {super.key,
      this.content,
      this.isHomeContent = true,
      this.scrollController,
      this.onViewAll});

  final dynamic content;
  final bool isHomeContent;
  final ScrollController? scrollController;
  final void Function(String title)? onViewAll;

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
              (!isHomeContent && onViewAll != null)
                  ? TextButton(
                      onPressed: () {
                        onViewAll?.call(title);
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
                key: PageStorageKey<String>('content-row-$title-$type'),
                controller: scrollController,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                cacheExtent: 520,
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
                      key: ValueKey<String>(
                          'content-artist-${artist.browseId}-$index'),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        ScreenNavigationSetup.openContentRouteSmart(
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
                    final album = content.albumList[index];
                    return ContentListItem(
                      key: ValueKey<String>(
                          'content-album-${album.browseId}-$index'),
                      content: album,
                    );
                  }
                  final playlist = content.playlistList[index];
                  return ContentListItem(
                    key: ValueKey<String>(
                        'content-playlist-${playlist.playlistId}-$index'),
                    content: playlist,
                  );
                }),
          ),
        ),
      ],
    );
  }
}
