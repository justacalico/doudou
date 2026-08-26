part of 'standard_player.dart';

class _CompactNowPlaying extends StatelessWidget {
  const _CompactNowPlaying({
    super.key,
    this.volumeAction,
  });

  final Widget? volumeAction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pc = Get.find<PlayerController>();
    const white = CupertinoColors.white;
    // Use the real screen width, not the MediaQuery-overridden one (the side
    // panel overrides MediaQuery to its own width, which would break the check)
    final realScreenWidth =
        View.of(context).physicalSize.width / View.of(context).devicePixelRatio;
    final isWideScreen = realScreenWidth > 800;
    final isInSlidingPanel = _isInSlidingPanel(context);
    final isLandscapeDense =
        !isWideScreen && size.width > size.height && size.height < 560;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Obx(() {
            if (pc.currentSong.value == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: BackgroundImage(
                key: Key("${pc.currentSong.value?.id}_background"),
                cacheHeight: 200,
              ),
            );
          }),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          isLandscapeDense
              ? SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        _buildTopActions(pc, white, dense: true,
                            isInSlidingPanel: isInSlidingPanel),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      if (song == null) {
                                        return const SizedBox(
                                            width: 76, height: 76);
                                      }
                                      return GestureDetector(
                                        onTap: () => pc.showLyrics(),
                                        onLongPress: () =>
                                            _showSongMore(context, pc),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: ImageWidget(
                                            size: 76,
                                            song: song,
                                            isPlayerArtImage: true,
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Obx(() {
                                        final song = pc.currentSong.value;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song?.title ?? '—',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: CupertinoColors.white,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              song?.artist ?? '—',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color:
                                                    CupertinoColors.systemGrey2,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: _CompactProgressBar(pc: pc, dense: true),
                              ),
                              _CompactControls(pc: pc, dense: true),
                            ],
                          ),
                        ),
                        PlayerMobileBottomBar(
                          volumeAction: volumeAction,
                          dense: true,
                          iconColor: white,
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildTopActions(pc, white,
                          isInSlidingPanel: isInSlidingPanel),
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Expanded(
                              flex: 3,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableHeight =
                                      constraints.maxHeight * 0.9;
                                  final artSize =
                                      (availableHeight < size.width * 0.75
                                              ? availableHeight
                                              : size.width * 0.75)
                                          .clamp(200.0, 350.0);
                                  return Obx(() {
                                    if (pc.currentSong.value == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Center(
                                      child: GestureDetector(
                                        onTap: () => pc.showLyrics(),
                                        onLongPress: () =>
                                            _showSongMore(context, pc),
                                        child: Container(
                                          width: artSize,
                                          height: artSize,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color: white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.32),
                                                blurRadius: 24,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(21),
                                            child: ImageWidget(
                                              size: artSize,
                                              song: pc.currentSong.value!,
                                              isPlayerArtImage: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 30),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      return Text(
                                        song?.title ?? '—',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: CupertinoColors.white,
                                          letterSpacing: -0.5,
                                          height: 1.0,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }),
                                    const SizedBox(height: 4),
                                    Obx(() {
                                      final song = pc.currentSong.value;
                                      return Text(
                                        song?.artist ?? '—',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: CupertinoColors.systemGrey,
                                          height: 1.0,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: _CompactProgressBar(pc: pc),
                      ),
                      const SizedBox(height: 24),
                      _CompactControls(pc: pc),
                      PlayerMobileBottomBar(
                        volumeAction: volumeAction,
                        iconColor: white,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTopActions(PlayerController pc, Color white,
      {bool dense = false, required bool isInSlidingPanel}) {
    final buttonSize = dense ? 34.0 : 40.0;
    final iconSize = dense ? 20.0 : 22.0;
    final borderRadius = dense ? 10.0 : 12.0;
    final horizontalPadding = dense ? 12.0 : 20.0;
    final verticalPadding = dense ? 4.0 : 10.0;
    final trailingGap = dense ? 6.0 : 8.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (isInSlidingPanel) {
                pc.playerPanelController.close();
              } else {
                Get.find<ShellController>().toggleNowPlayingFullscreen();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: white.withValues(alpha: 0.18),
                    width: 0.5,
                  ),
                ),
                child: isInSlidingPanel
                    ? Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: white,
                        size: iconSize,
                      )
                    : Obx(
                        () => Icon(
                          Get.find<ShellController>()
                                  .isNowPlayingFullscreen
                                  .value
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: white,
                          size: iconSize,
                        ),
                      ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!GetPlatform.isDesktop)
                GestureDetector(
                  onTap: () => pc.queuePanelController.open(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      margin: EdgeInsets.only(right: trailingGap),
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: white.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: white,
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              Obx(() => GestureDetector(
                    onTap: pc.toggleFavourite,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(borderRadius),
                          border: Border.all(
                            color: white.withValues(alpha: 0.18),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          pc.isCurrentSongFav.isTrue
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: pc.isCurrentSongFav.isTrue
                              ? const Color(0xFFEC4899)
                              : white,
                          size: iconSize,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  void _showSongMore(BuildContext context, PlayerController pc) {
    if (pc.currentSong.value == null) return;
    showModalBottomSheet(
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      isScrollControlled: true,
      context: context,
      barrierColor: Colors.transparent.withAlpha(100),
      builder: (ctx) => SongInfoBottomSheet(
        pc.currentSong.value!,
        calledFromPlayer: true,
      ),
    ).whenComplete(() => Get.delete<SongInfoController>());
  }
}
