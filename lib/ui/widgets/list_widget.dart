import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/album.dart';
import '/ui/models/content_category.dart';
import '../../models/artist.dart';
import '../../models/playling_from.dart';
import '../../models/playlist.dart';
import '../navigator.dart';
import '../player/player_controller.dart';
import 'image_widget.dart';
import 'song_list_tile.dart';
import 'songinfo_bottom_sheet.dart';
import '/utils/helper.dart';

class ListWidget extends StatelessWidget with RemoveSongFromPlaylistMixin {
  const ListWidget(this.items, this.title, this.isCompleteList,
      {super.key,
      this.isPlaylistOrAlbum = false,
      this.isArtistSongs = false,
      this.playlist,
      this.album,
      this.artist,
      this.scrollController});
  final List<dynamic> items;
  final String title;
  final bool isCompleteList;
  final ScrollController? scrollController;

  /// Valid for songlist
  final bool isArtistSongs;
  final bool isPlaylistOrAlbum;
  final Playlist? playlist;
  final Album? album;
  final Artist? artist;

  @override
  Widget build(BuildContext context) {
    final category = ContentCategoryMapper.fromKey(title);
    if (items.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            "No ${category.localizedLabel(context).toLowerCase()}!",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      );
    } else if (category.isSongLike) {
      return isCompleteList
          ? Expanded(
              child: listViewSongVid(items,
                  isPlaylistOrAlbum: isPlaylistOrAlbum,
                  playlist: playlist,
                  album: album,
                  artist: artist,
                  sc: scrollController,
                  isArtistSongs: isArtistSongs))
          : SizedBox(
              height: items.length * 75.0,
              child: listViewSongVid(items),
            );
    } else if (category.isPlaylistLike) {
      return listViewPlaylists(items, sc: scrollController);
    } else if (category.isAlbumLike) {
      return listViewAlbums(items, sc: scrollController);
    } else if (category.isArtistLike) {
      return isCompleteList
          ? Expanded(child: listViewArtists(items, sc: scrollController))
          : SizedBox(
              height: items.length * 95.0,
              child: listViewArtists(items),
            );
    }
    return const SizedBox.shrink();
  }

  Widget listViewSongVid(List<dynamic> items,
      {bool isPlaylistOrAlbum = false,
      Playlist? playlist,
      Album? album,
      Artist? artist,
      bool isArtistSongs = false,
      ScrollController? sc}) {
    final playerController = Get.find<PlayerController>();
    return ListView.builder(
      key: PageStorageKey<String>('song-list-$title-$isCompleteList'),
      padding: const EdgeInsets.only(
        bottom: 200,
        top: 0,
      ),
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      cacheExtent: 720,
      controller: sc,
      itemCount: items.length,
      physics: isCompleteList
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final mediaItem = items[index] as MediaItem;
        return SongListTile(
          key: ValueKey<String>('song-tile-${mediaItem.id}-$index'),
          song: mediaItem,
          onTap: () {
            isArtistSongs
                // if song is from artist then play from artist
                ? playerController.playPlayListSong(
                    List<MediaItem>.from(items), index,
                    playfrom: PlaylingFrom(
                        type: PlaylingFromType.ARTIST,
                        name: artist?.name ?? "........."))
                :
                // if playlist is not null then play from playlist else play from album
                playlist != null && album == null
                    ? playerController.playPlayListSong(
                        List<MediaItem>.from(items), index,
                        playfrom: PlaylingFrom(
                          type: PlaylingFromType.PLAYLIST,
                          name: playlist.title,
                        ))
                    : playerController
                        .pushSongToQueue(items[index] as MediaItem);
          },
        );
      },
    );
  }

  Widget listViewPlaylists(List<dynamic> playlists, {ScrollController? sc}) {
    return Expanded(
      child: ListView.builder(
          key: PageStorageKey<String>('playlist-list-$title-$isCompleteList'),
          padding: const EdgeInsets.only(
            bottom: 210,
            top: 0,
          ),
          controller: sc,
          cacheExtent: 600,
          itemCount: playlists.length,
          itemExtent: 120,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => wideListTile(context,
              key: ValueKey<String>(
                  'playlist-row-${playlists[index].playlistId}-$index'),
              playlist: playlists[index],
              title: playlists[index].title,
              subtitle: playlists[index]?.description ?? "NA",
              subtitle2: "")),
    );
  }

  Widget listViewAlbums(List<dynamic> albums, {ScrollController? sc}) {
    final albumMeta = albums
        .map<Map<String, String>>((album) => {
              'title': album.title.toString(),
              'subtitle': _computeAlbumArtistSubtitle(album),
            })
        .toList(growable: false);
    return Expanded(
      child: ListView.builder(
          key: PageStorageKey<String>('album-list-$title-$isCompleteList'),
          padding: const EdgeInsets.only(
            bottom: 210,
            top: 0,
          ),
          controller: sc,
          cacheExtent: 600,
          itemCount: albums.length,
          itemExtent: 120,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final subtitle = albumMeta[index]['subtitle'] ?? '';
            return wideListTile(context,
                key: ValueKey<String>(
                    'album-row-${albums[index].browseId}-$index'),
                album: albums[index],
                title: albums[index].title,
                subtitle: subtitle,
                subtitle2: albums[index].artists.isEmpty
                    ? "${albums[index].year}"
                    : "${(albums[index].artists[0]['name'])} • ${albums[index].year}");
          }),
    );
  }

  Widget listViewArtists(List<dynamic> artists, {ScrollController? sc}) {
    return ListView.builder(
      key: PageStorageKey<String>('artist-list-$title-$isCompleteList'),
      padding: const EdgeInsets.only(
        bottom: 200,
        top: 5,
      ),
      controller: sc,
      cacheExtent: 720,
      itemCount: artists.length,
      itemExtent: 90,
      physics: isCompleteList
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => ListTile(
        key: ValueKey<String>('artist-row-${artists[index].browseId}-$index'),
        visualDensity: const VisualDensity(horizontal: -2, vertical: 2),
        onTap: () {
          ScreenNavigationSetup.pushContentRoute(
              ScreenNavigationSetup.artistScreen,
              arguments: [false, artists[index]]);
        },
        contentPadding: const EdgeInsets.only(top: 0, bottom: 0, left: 5),
        leading: ImageWidget(
          size: 90,
          artist: artists[index],
        ),
        title: Text(
          artists[index].name,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          artists[index].subscribers,
          maxLines: 2,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }

  String _computeAlbumArtistSubtitle(dynamic album) {
    try {
      final artists = album.artists as List<dynamic>? ?? const [];
      if (artists.length <= 1) return "";
      final joined = artists
          .skip(1)
          .map((item) => item['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(',');
      return joined.length > 16 ? joined.substring(0, 16) : joined;
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=listWidget.albums.composeArtistName] Failed to compose artist names for album=${album.title}: $e\n$st');
      return "";
    }
  }

  Widget wideListTile(BuildContext context,
      {dynamic album,
      dynamic playlist,
      Key? key,
      required String title,
      required String subtitle,
      required String subtitle2}) {
    return InkWell(
      key: key,
      onTap: () {
        if (album != null) {
          ScreenNavigationSetup.pushContentRoute(
              ScreenNavigationSetup.albumScreen,
              arguments: (album, album.browseId));
        } else {
          ScreenNavigationSetup.pushContentRoute(
              ScreenNavigationSetup.playlistScreen,
              arguments: [playlist, playlist.playlistId]);
        }
      },
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 10),
          child: Row(
            children: [
              ImageWidget(
                size: 100,
                album: album,
                playlist: playlist,
              ),
              const SizedBox(
                width: 20,
              ),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      subtitle2,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ))
            ],
          ),
        ),
      ),
    );
  }
}
