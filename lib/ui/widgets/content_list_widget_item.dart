import 'package:flutter/material.dart';

import '../navigator.dart';
import 'image_widget.dart';

String _albumSubtitle(dynamic content) {
  final artists = content.artists;
  final year = content.year?.toString().trim();
  final name = (artists != null && artists.isNotEmpty)
      ? (artists[0]['name']?.toString() ?? '').trim()
      : '';
  final parts = [name, if (year != null && year.isNotEmpty) year];
  return parts.where((s) => s.isNotEmpty).join(' | ');
}

class ContentListItem extends StatelessWidget {
  const ContentListItem(
      {super.key, required this.content, this.isLibraryItem = false});

  ///content will be of Type class Album or Playlist
  final dynamic content;
  final bool isLibraryItem;

  String _subtitle(bool isAlbum) {
    if (isLibraryItem) return "";
    if (isAlbum) return _albumSubtitle(content);
    return content.description ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final isAlbum = content.runtimeType.toString() == "Album";
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = isLibraryItem ? constraints.maxWidth : 130.0;
      final maxByHeight = constraints.hasBoundedHeight
          ? (constraints.maxHeight - 72).clamp(88.0, 180.0)
          : 180.0;
      final imageSize =
          isLibraryItem ? (cardWidth - 10).clamp(92.0, maxByHeight) : 112.0;
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () {
            if (isAlbum) {
              ScreenNavigationSetup.openContentRouteSmart(
                  ScreenNavigationSetup.albumScreen,
                  arguments: (content, content.browseId));
              return;
            }
            ScreenNavigationSetup.openContentRouteSmart(
                ScreenNavigationSetup.playlistScreen,
                arguments: [content, content.playlistId]);
          },
          child: SizedBox(
            width: isLibraryItem ? double.infinity : 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isAlbum
                      ? ImageWidget(
                          size: imageSize,
                          album: content,
                        )
                      : content.isCloudPlaylist ||
                              !(content.playlistId == 'LIBRP' ||
                                  content.playlistId == 'LIBFAV' ||
                                  content.playlistId == 'SongsCache' ||
                                  content.playlistId == 'SongDownloads')
                          ? SizedBox.square(
                              dimension: imageSize,
                              child: Stack(
                                children: [
                                  ImageWidget(
                                    size: imageSize,
                                    playlist: content,
                                  ),
                                  if (content.isPipedPlaylist)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          height: 18,
                                          width: 18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                          child: Center(
                                              child: Text(
                                            "P",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(fontSize: 14),
                                          )),
                                        ),
                                      ),
                                    ),
                                  if (!content.isCloudPlaylist)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          height: 18,
                                          width: 18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                          child: Center(
                                              child: Text(
                                            "L",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(fontSize: 14),
                                          )),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            )
                          : Container(
                              height: imageSize,
                              width: imageSize,
                              decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColorLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Center(
                                  child: Icon(
                                content.playlistId == 'LIBRP'
                                    ? Icons.history
                                    : content.playlistId == 'LIBFAV'
                                        ? Icons.favorite
                                        : content.playlistId == 'SongsCache'
                                            ? Icons.flight
                                            : Icons.download,
                                color: Colors.white,
                                size: 40,
                              ))),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        _subtitle(isAlbum),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
