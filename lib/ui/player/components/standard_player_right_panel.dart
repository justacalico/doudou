part of 'standard_player.dart';

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.pc,
    required this.textColor,
    required this.mutedColor,
  });

  final PlayerController pc;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TabBar(
              labelColor: textColor,
              unselectedLabelColor: mutedColor,
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: context.l10n.upNext),
                Tab(text: context.l10n.lyrics),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  context.l10n.playingFrom,
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                Expanded(
                  child: Obx(() => Text(
                        pc.playinfrom.value.nameString,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _UpNextList(
                    pc: pc, textColor: textColor, mutedColor: mutedColor),
                Obx(() => pc.isLyricsLoading.isTrue
                    ? const Center(child: LoadingIndicator())
                    : _LyricsPanel(pc: pc)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
