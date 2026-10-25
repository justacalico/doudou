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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
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
      ),
    );
  }
}
