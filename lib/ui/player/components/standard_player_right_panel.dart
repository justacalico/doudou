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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.lyrics,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: textColor),
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
        const Expanded(
          child: _LyricsPanel(),
        ),
      ],
    );
  }
}
