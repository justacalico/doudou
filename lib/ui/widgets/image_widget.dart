import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/Settings/settings_screen_controller.dart';
import '/models/artist.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';

class ImageWidget extends StatelessWidget {
  const ImageWidget({
    super.key,
    this.song,
    this.playlist,
    this.album,
    this.artist,
    required this.size,
    this.isPlayerArtImage = false,
  });
  final MediaItem? song;
  final Playlist? playlist;
  final Album? album;
  final bool isPlayerArtImage;
  final Artist? artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    String imageUrl = song != null
        ? song!.artUri.toString()
        : playlist != null
            ? playlist!.thumbnailUrl
            : album != null
                ? album!.thumbnailUrl
                : artist != null
                    ? artist!.thumbnailUrl
                    : "";
    // String cacheKey = song != null
    //     ? "${song!.id}_song"
    //     : playlist != null
    //         ? "${playlist!.playlistId}_playlist"
    //         : album != null
    //             ? "${album!.browseId}_album"
    //             : artist != null
    //                 ? "${artist!.browseId}_artist"
    //                 : "";

    final bool offlineAvailable =
        song != null && (song?.extras?["url"] ?? "").contains("file");
    final offlineThumbFile = song == null
        ? null
        : File(
            "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${song!.id}.png");

    Widget placeholderIcon() {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: artist != null ? null : BorderRadius.circular(10),
        ),
        child: Image.asset(
            "assets/icons/${song != null ? "song" : artist != null ? "artist" : "album"}.png"),
      );
    }

    Widget placeholder() {
      if (!isPlayerArtImage) return placeholderIcon();
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
        child: const SizedBox.expand(),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(64, isPlayerArtImage ? 800 : 220);
    final cacheKey = song != null
        ? "${song!.id}_song"
        : playlist != null
            ? "${playlist!.playlistId}_playlist"
            : album != null
                ? "${album!.browseId}_album"
                : artist != null
                    ? "${artist!.browseId}_artist"
                    : null;

    return Container(
      height: size,
      width: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: artist != null ? null : BorderRadius.circular(5),
      ),
      child: offlineAvailable
          ? (offlineThumbFile != null &&
                  offlineThumbFile.existsSync()
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: artist != null
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: artist != null
                        ? null
                        : BorderRadius.circular(5),
                    image: DecorationImage(
                      image: FileImage(offlineThumbFile),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : placeholderIcon())
          : imageUrl.trim().isEmpty
              ? placeholder()
              : CachedNetworkImage(
                  memCacheHeight: cachePx,
                  memCacheWidth: cachePx,
                  cacheKey: cacheKey,
                  imageUrl: imageUrl,
                  imageBuilder: (context, imageProvider) => DecoratedBox(
                    decoration: BoxDecoration(
                      shape: artist != null
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: artist != null
                          ? null
                          : BorderRadius.circular(5),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  useOldImageOnUrlChange: true,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  errorWidget: (context, url, error) => placeholder(),
                  progressIndicatorBuilder: ((_, __, ___) => placeholder()),
                ),
    );
  }
}
