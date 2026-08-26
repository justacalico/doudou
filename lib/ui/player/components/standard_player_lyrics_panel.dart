part of 'standard_player.dart';

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.pc});

  final PlayerController pc;

  @override
  Widget build(BuildContext context) {
    return const LyricsWidget(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
  }
}
