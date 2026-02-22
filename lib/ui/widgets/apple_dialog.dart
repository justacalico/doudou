import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:doudou/ui/theme.dart';

/// Apple-style two-choice dialog. Returns true for [primaryLabel], false for [secondaryLabel], null if dismissed.
Future<bool?> showAppleChoiceDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String secondaryLabel,
  required String primaryLabel,
  bool primaryIsDestructive = false,
}) async {
  return showGeneralDialog<bool?>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: title,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _AppleDialogContent(
            title: title,
            content: Text(
              message,
              style: TextStyle(
                color: DesktopTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(secondaryLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: primaryIsDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(primaryLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Apple-style confirmation dialog. Returns true if confirmed, false if cancelled, null if dismissed.
Future<bool?> showAppleConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  return showGeneralDialog<bool?>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: title,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _AppleDialogContent(
            title: title,
            content: Text(
              message,
              style: TextStyle(
                color: DesktopTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Apple-style dialog: frosted glass, large radius, soft shadow.
/// Use [showAppleDialog] to present with barrier blur.
void showAppleDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  double? width,
  double? maxHeight,
  bool barrierDismissible = true,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black54,
    barrierLabel: title,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _AppleDialogContent(
            title: title,
            content: content,
            actions: actions,
            width: width,
            maxHeight: maxHeight,
          ),
        ),
      );
    },
  );
}

class _AppleDialogContent extends StatelessWidget {
  const _AppleDialogContent({
    required this.title,
    required this.content,
    this.actions,
    this.width,
    this.maxHeight,
  });

  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double? width;
  final double? maxHeight;

  static const double _radius = 20;
  static const double _blurSigma = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.04);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: width ?? 320,
              maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              color: bgColor,
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DesktopTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: content,
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: a,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single selectable row for use inside Apple-style dialogs (e.g. language or theme).
/// Shows a checkmark or filled circle when [selected].
class AppleDialogOption extends StatelessWidget {
  const AppleDialogOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: accent,
                      )
                    : Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesktopTheme.textTertiary,
                            width: 1.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
