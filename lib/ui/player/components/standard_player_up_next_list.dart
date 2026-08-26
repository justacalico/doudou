part of 'standard_player.dart';

class _UpNextList extends StatelessWidget {
  const _UpNextList({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final queue = pc.currentQueue;
      final currentIndex = pc.currentSongIndex.value;
      if (queue.isEmpty) {
        return Center(
          child: Text(
            context.l10n.songs,
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
        );
      }
      final current = currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;
      final queueIndices = List.generate(queue.length, (i) => i);

      return LayoutBuilder(
        builder: (context, constraints) {
          final showPinnedCurrent =
              current != null && constraints.maxHeight >= 180;
          return Column(
            children: [
              if (showPinnedCurrent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        ImageWidget(size: 44, song: current),
                        const SizedBox(width: 10),
                        Icon(Icons.graphic_eq_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                current.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                current.artist ?? '—',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: queueIndices.length,
                  itemBuilder: (context, index) {
                    final i = queueIndices[index];
                    final item = queue[i];
                    final isCurrent = i == currentIndex;
                    final primary = Theme.of(context).colorScheme.primary;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? primary.withValues(alpha: 0.22)
                                : Colors.transparent,
                            border: Border.all(
                              color: isCurrent
                                  ? primary.withValues(alpha: 0.65)
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              if (isCurrent)
                                Container(
                                  width: 4,
                                  height: 60,
                                  color: primary,
                                ),
                              Expanded(
                                child: ListTile(
                                  dense: true,
                                  leading: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: ImageWidget(size: 40, song: item),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    item.artist ?? '—',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrent
                                          ? mutedColor.withValues(alpha: 0.95)
                                          : mutedColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => pc.seekByIndex(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
