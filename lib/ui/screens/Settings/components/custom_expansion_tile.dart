import 'dart:ui';
import 'package:flutter/material.dart';

class CustomExpansionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Key? expansionKey;
  final ValueChanged<bool>? onExpansionChanged;
  const CustomExpansionTile(
      {super.key,
      required this.children,
      required this.icon,
      required this.title,
      this.expansionKey,
      this.onExpansionChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                onExpansionChanged: onExpansionChanged,
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                textColor: theme.textTheme.titleMedium!.color,
                iconColor: theme.textTheme.titleMedium!.color,
                collapsedIconColor: theme.textTheme.titleMedium!.color!.withValues(alpha: 0.7),
                collapsedTextColor: theme.textTheme.titleMedium!.color!.withValues(alpha: 0.7),
                title: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: theme.colorScheme.primary),
                ),
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
