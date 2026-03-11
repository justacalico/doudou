import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '../../screens/Settings/settings_screen_controller.dart';
import '/app/theme/now_playing_accent_provider.dart';
import '../player_controller.dart';

class BackgroundImage extends ConsumerWidget {
  const BackgroundImage({super.key, this.cacheHeight});

  final int? cacheHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GetX<PlayerController>(
      builder: (playerController) => SizedBox.expand(
        /// if song is null then return empty container
        child: playerController.currentSong.value != null

            /// if song is local then return image from local file
            ? (playerController.currentSong.value!.extras!['url'] ?? '')
                    .contains('file')
                ? Builder(builder: (context) {
                    final imgFile = File(
                        "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${playerController.currentSong.value!.id}.png");
                    return FutureBuilder(
                      future: imgFile.exists(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData &&
                            snapshot.data == true) {
                          ref
                              .read(nowPlayingAccentProvider.notifier)
                              .setFromArtwork(
                                FileImage(imgFile),
                                playerController.currentSong.value!.id,
                              );

                          return Image.file(
                            imgFile,
                            cacheHeight: cacheHeight,
                            fit: BoxFit.cover,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  })

                /// else return image from network
                : CachedNetworkImage(
                    memCacheHeight: cacheHeight,
                    imageBuilder: (context, imageProvider) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(nowPlayingAccentProvider.notifier)
                            .setFromArtwork(
                              imageProvider,
                              playerController.currentSong.value!.id,
                            );
                      });
                      return Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      );
                    },
                    imageUrl:
                        playerController.currentSong.value!.artUri.toString(),
                    cacheKey: "${playerController.currentSong.value!.id}_song",
                  )
            : Container(),
      ),
    );
  }
}
