import 'package:flutter/material.dart';

import '/ui/design/doudou_colors.dart';
import '/ui/design/doudou_tokens.dart';

class NightlyBuildBadge extends StatelessWidget {
  const NightlyBuildBadge({
    super.key,
    required this.isNightly,
    required this.label,
  });

  final bool isNightly;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isNightly) return const SizedBox.shrink();

    final colors = context.doudouColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.nights_stay,
          size: 14,
          color: colors.warning,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: DoudouType.meta.copyWith(
            color: colors.warning,
          ),
        ),
      ],
    );
  }
}
