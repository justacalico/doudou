part of 'standard_player.dart';

mixin _StandardPlayerStateBuildMixin on _StandardPlayerStateBase {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = _resolveNowPlayingMode(constraints);
        if (mode != _NowPlayingMode.compact) {
          final metrics = _NowPlayingLayoutMetrics.from(constraints);
          return _ExpandedNowPlaying(
            key: const Key('expanded'),
            metrics: metrics,
          );
        }
        final pc = Get.find<PlayerController>();
        return Stack(
          children: [
            _CompactNowPlaying(
              key: const Key('compact'),
              volumeAction: IconButton(
                onPressed: () {
                  setState(
                      () => _showMobileVolumePanel = !_showMobileVolumePanel);
                },
                icon: Obx(() {
                  final v = pc.volume.value;
                  return Icon(
                    v == 0
                        ? Icons.volume_off_rounded
                        : v < 50
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 26,
                  );
                }),
                color: _showMobileVolumePanel
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                tooltip: "Volume",
              ),
            ),
            if (_showMobileVolumePanel)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showMobileVolumePanel = false),
                  child: const SizedBox.expand(),
                ),
              ),
            if (_showMobileVolumePanel)
              Positioned(
                left: 42,
                right: 42,
                bottom: 78,
                child: _MobileVolumeOverlay(
                  onTapOutside: () =>
                      setState(() => _showMobileVolumePanel = false),
                ),
              ),
          ],
        );
      },
    );
  }
}
