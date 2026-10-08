import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/Settings/settings_screen_controller.dart';
import '/models/artist.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';

class ImageWidget extends StatefulWidget {
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
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  File? _offlineThumbFile;
  bool _offlineThumbExists = false;

  @override
  void initState() {
    super.initState();
    _resolveOfflineThumb();
  }

  @override
  void didUpdateWidget(ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) {
      _resolveOfflineThumb();
    }
  }

  void _resolveOfflineThumb() {
    final song = widget.song;
    // Preloaded and lock-cached songs also carry a file url, but only user
    // downloads come with a saved thumbnail. The existence check runs async:
    // a synchronous stat inside build used to stall the UI thread once per
    // visible tile on every rebuild while scrolling.
    if (song == null ||
        !(song.extras?["url"] ?? "").toString().contains("file")) {
      _offlineThumbFile = null;
      _offlineThumbExists = false;
      return;
    }
    final file = File(
        "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${song.id}.png");
    _offlineThumbFile = file;
    _offlineThumbExists = false;
    file.exists().then((exists) {
      if (!mounted || _offlineThumbFile?.path != file.path) return;
      if (exists != _offlineThumbExists) {
        setState(() => _offlineThumbExists = exists);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final playlist = widget.playlist;
    final album = widget.album;
    final artist = widget.artist;
    String imageUrl = song != null
        ? song.artUri.toString()
        : playlist != null
            ? playlist.thumbnailUrl
            : album != null
                ? album.thumbnailUrl
                : artist != null
                    ? artist.thumbnailUrl
                    : "";

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
      if (!widget.isPlayerArtImage) return placeholderIcon();
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
        child: const SizedBox.expand(),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (widget.size * dpr)
        .round()
        .clamp(64, widget.isPlayerArtImage ? 800 : 220);
    final cacheKey = song != null
        ? "${song.id}_song"
        : playlist != null
            ? "${playlist.playlistId}_playlist"
            : album != null
                ? "${album.browseId}_album"
                : artist != null
                    ? "${artist.browseId}_artist"
                    : null;

    return Container(
      height: widget.size,
      width: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: artist != null ? null : BorderRadius.circular(5),
      ),
      child: _offlineThumbExists
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: artist != null
                    ? null
                    : BorderRadius.circular(5),
                image: DecorationImage(
                  image: FileImage(_offlineThumbFile!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : imageUrl.trim().isEmpty
              ? placeholder()
              : CachedNetworkImage(
                  memCacheWidth: cacheWidth,
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
