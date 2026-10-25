import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import '../design/doudou_colors.dart';

class ProceedButton extends StatelessWidget {
  const ProceedButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
  });
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.doudouColors;
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
          color: enabled ? colors.accentPrimary : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
          child: Text(
            buttonText,
            style: TextStyle(
                color: enabled ? colors.onAccent : colors.textDisabled),
          ),
        ),
      ),
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Text(
          context.l10n.cancel,
          style: TextStyle(color: context.doudouColors.textSecondary),
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
         if (onPressed != null) {
          onPressed!();
        }
      },
    );
  }
}
