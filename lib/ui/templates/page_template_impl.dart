import 'package:flutter/material.dart';
import 'package:doudou/ui/theme.dart';

/// Modern page template with gradient header and glass effects
class PageTemplate extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final String? subtitle;
  final bool showGradientHeader;

  const PageTemplate({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.padding,
    this.showBackButton = false,
    this.onBackPressed,
    this.subtitle,
    this.showGradientHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern header with gradient option
        Container(
          padding: const EdgeInsets.fromLTRB(
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingMd,
          ),
          decoration: showGradientHeader ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ) : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              
              if (isNarrow && actions != null && actions!.isNotEmpty) {
                // Stack layout for narrow screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: DesktopTheme.spacingMd),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: actions!.map((action) => Padding(
                          padding: const EdgeInsets.only(right: DesktopTheme.spacingSm),
                          child: action,
                        )).toList(),
                      ),
                    ),
                  ],
                );
              }
              
              // Normal row layout
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showBackButton) ...[
                    _ModernBackButton(onPressed: onBackPressed),
                    const SizedBox(width: DesktopTheme.spacingMd),
                  ],
                  // Title with minimum width to prevent wrapping
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: DesktopTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: DesktopTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: DesktopTheme.spacingMd),
                  if (actions != null) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions!.map((action) => Padding(
                            padding: const EdgeInsets.only(left: DesktopTheme.spacingSm),
                            child: action,
                          )).toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                ],
              );
            },
          ),
        ),
        
        // Subtle gradient divider
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                DesktopTheme.glassBorder,
                Colors.transparent,
              ],
            ),
          ),
        ),
        
        // Page content
        Expanded(
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(
              horizontal: DesktopTheme.spacingLg,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Modern section header with gradient text option
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onSeeAllPressed;
  final bool useGradient;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onSeeAllPressed,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DesktopTheme.spacingMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (useGradient)
                  DesktopGradientText(
                    text: title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                  )
                else
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: DesktopTheme.textPrimary,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesktopTheme.spacingXs),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: DesktopTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) 
            trailing!
          else if (onSeeAllPressed != null)
            _ModernSeeAllButton(onPressed: onSeeAllPressed!),
        ],
      ),
    );
  }
}

/// Modern back button with hover effect
class _ModernBackButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _ModernBackButton({this.onPressed});

  @override
  State<_ModernBackButton> createState() => _ModernBackButtonState();
}

class _ModernBackButtonState extends State<_ModernBackButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed ?? () => Navigator.of(context).pop(),
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            border: Border.all(
              color: _isHovered
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : DesktopTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: _isHovered
                    ? theme.colorScheme.primary
                    : DesktopTheme.textSecondary,
              ),
              const SizedBox(width: DesktopTheme.spacingSm),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isHovered
                      ? theme.colorScheme.primary
                      : DesktopTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern "See All" button with hover animation
class _ModernSeeAllButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ModernSeeAllButton({required this.onPressed});

  @override
  State<_ModernSeeAllButton> createState() => _ModernSeeAllButtonState();
}

class _ModernSeeAllButtonState extends State<_ModernSeeAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusRound),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: DesktopTheme.spacingXs),
              AnimatedSlide(
                duration: DesktopTheme.durationFast,
                offset: _isHovered ? const Offset(0.2, 0) : Offset.zero,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}