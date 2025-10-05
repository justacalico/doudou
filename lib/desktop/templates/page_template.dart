import 'package:flutter/material.dart';

class PageTemplate extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool showBackButton;

  const PageTemplate({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.padding,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page header
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        
        // Page content
        Expanded(
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}