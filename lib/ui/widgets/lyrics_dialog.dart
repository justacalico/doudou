import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '/utils/app_l10n.dart';
import '/ui/player/components/lyrics_switch.dart';
import '/ui/player/components/lyrics_widget.dart';
import '/ui/widgets/common_dialog_widget.dart';


class LyricsDialog extends StatelessWidget {
  const LyricsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommonDialog(
      maxWidth: 700,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: _LyricsHeader(),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LyricsSwitch(),
          ),
          Flexible(
            child: LyricsWidget(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16))
          ),
        ]),
    );
  }
}

class _LyricsHeader extends StatelessWidget {
  const _LyricsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          context.l10n.lyrics,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
