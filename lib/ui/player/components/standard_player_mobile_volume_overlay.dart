part of 'standard_player.dart';

class _MobileVolumeOverlay extends StatelessWidget {
  const _MobileVolumeOverlay({required this.onTapOutside});

  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Obx(() {
            final v = pc.volume.value;
            return Row(
              children: [
                Icon(
                  v == 0
                      ? Icons.volume_off_rounded
                      : v < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: theme.colorScheme.onSurface,
                      inactiveTrackColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      thumbColor: theme.colorScheme.onSurface,
                    ),
                    child: Slider(
                      value: v / 100,
                      onChanged: (value) {
                        pc.setVolume((value * 100).round().clamp(0, 100));
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
