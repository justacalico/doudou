part of 'standard_player.dart';

class _CompactProgressBar extends StatelessWidget {
  const _CompactProgressBar({
    required this.pc,
    this.dense = false,
  });

  final PlayerController pc;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = pc.progressBarStatus.value;
      final total = status.total;
      final current = status.current;
      final progress = total.inMilliseconds > 0
          ? (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      void seekTo(Offset localPos, RenderBox box) {
        final w = box.size.width;
        if (w > 0 && total.inMilliseconds > 0) {
          final frac = (localPos.dx / w).clamp(0.0, 1.0);
          pc.seek(
              Duration(milliseconds: (frac * total.inMilliseconds).round()));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekTo(
                d.localPosition, context.findRenderObject() as RenderBox),
            onHorizontalDragUpdate: (d) => seekTo(
                d.localPosition, context.findRenderObject() as RenderBox),
            child: SizedBox(
              height: dense ? 30 : 44,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: dense ? 6 : 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white
                                      .withValues(alpha: 0.86),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(current),
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.6),
                    fontSize: dense ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(total),
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.6),
                    fontSize: dense ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
