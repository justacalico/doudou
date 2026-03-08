import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/content_category.dart';
import '../screens/Search/search_result_screen_controller.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/media_Item_builder.dart';
import '/ui/widgets/content_list_widget.dart';
import 'separate_tab_item_widget.dart';

class ResultWidget extends StatelessWidget {
  const ResultWidget({
    super.key,
    this.isv2Used = false,
    required this.searchResScrController,
  });
  final bool isv2Used;
  final SearchResultScreenController searchResScrController;

  @override
  Widget build(BuildContext context) {
    final topPadding = context.isLandscape ? 50.0 : 80.0;
    return Obx(
      () => Center(
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: SingleChildScrollView(
            padding:
                EdgeInsets.only(bottom: 200, top: isv2Used ? 0 : topPadding),
            child: searchResScrController.isResultContentFetced.value
                ? Column(children: [
                    if (!isv2Used)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.searchRes,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    if (!isv2Used)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "${context.l10n.for1} \"${searchResScrController.queryString.value}\"",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(
                      height: 10,
                    ),
                    ...generateWidgetList(searchResScrController),
                  ])
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  List<Widget> generateWidgetList(
      SearchResultScreenController searchResScrController) {
    List<Widget> list = [];
    for (dynamic item in searchResScrController.resultContent.entries) {
      final category = ContentCategoryMapper.fromKey(item.key.toString());
      if (category.isSongLike) {
        list.add(SeparateTabItemWidget(
          items: _toMediaItemList(item.value),
          title: item.key,
          isCompleteList: false,
          searchResultController: searchResScrController,
        ));
      } else if (category == ContentCategory.albums) {
        list.add(ContentListWidget(
          content: AlbumContent(
              title: item.key, albumList: _toAlbumList(item.value)),
          isHomeContent: false,
          onViewAll: searchResScrController.viewAllCallback,
        ));
      } else if (category.isArtistLike) {
        list.add(SeparateTabItemWidget(
          items: _toArtistList(item.value),
          title: item.key,
          isCompleteList: false,
          searchResultController: searchResScrController,
        ));
      }
    }

    return list;
  }

  static List<MediaItem> _toMediaItemList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <MediaItem>[];
    for (final e in value) {
      if (e is MediaItem) {
        out.add(e);
      } else if (e is Map) {
        out.add(MediaItemBuilder.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<Album> _toAlbumList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <Album>[];
    for (final e in value) {
      if (e is Album) {
        out.add(e);
      } else if (e is Map) {
        out.add(Album.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<Artist> _toArtistList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <Artist>[];
    for (final e in value) {
      if (e is Artist) {
        out.add(e);
      } else if (e is Map) {
        out.add(Artist.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }
}
