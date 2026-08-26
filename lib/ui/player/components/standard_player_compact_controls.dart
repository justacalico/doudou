part of 'standard_player.dart';

class _CompactControls extends StatelessWidget {
  const _CompactControls({
    required this.pc,
    this.dense = false,
  });

  final PlayerController pc;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    final horizontalPadding = dense ? 18.0 : 40.0;
    final sideIconSize = dense ? 20.0 : 24.0;
    final skipIconSize = dense ? 30.0 : 36.0;
    final playButtonSize = dense ? 56.0 : 72.0;
    final playIconSize = dense ? 30.0 : 36.0;
    final gapSmall = dense ? 6.0 : 8.0;
    final gapMedium = dense ? 10.0 : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(() => GestureDetector(
                onTap: pc.toggleShuffleMode,
                child: Icon(
                  Icons.shuffle_rounded,
                  color: pc.isShuffleModeEnabled.isTrue
                      ? white
                      : white.withValues(alpha: 0.6),
                  size: sideIconSize,
                ),
              )),
          SizedBox(width: gapSmall),
          GestureDetector(
            onTap: pc.prev,
            child: Icon(
              Icons.skip_previous_rounded,
              color: white,
              size: skipIconSize,
            ),
          ),
          SizedBox(width: gapMedium),
          Obx(() {
            final playing = pc.buttonState.value == PlayButtonState.playing;
            return GestureDetector(
              onTap: () => pc.playPause(),
              child: Container(
                width: playButtonSize,
                height: playButtonSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: white.withValues(alpha: 0.24),
                    width: 0.6,
                  ),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: white,
                  size: playIconSize,
                ),
              ),
            );
          }),
          SizedBox(width: gapMedium),
          GestureDetector(
            onTap: pc.next,
            child: Icon(
              Icons.skip_next_rounded,
              color: white,
              size: skipIconSize,
            ),
          ),
          SizedBox(width: gapSmall),
          Obx(() => GestureDetector(
                onTap: pc.toggleLoopMode,
                child: Icon(
                  pc.isLoopModeEnabled.isTrue
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: pc.isLoopModeEnabled.isTrue
                      ? white
                      : white.withValues(alpha: 0.6),
                  size: sideIconSize,
                ),
              )),
        ],
      ),
    );
  }
}
