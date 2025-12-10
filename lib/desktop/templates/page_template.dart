import 'package:flutter/material.dart';
import '../../widgets/apple_design/apple_theme.dart';

/// Apple-styled page template with large title navigation and smooth transitions
class PageTemplate extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const PageTemplate({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.padding,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple-style large title header
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppleDesignSystem.spacing24,
            AppleDesignSystem.spacing16,
            AppleDesignSystem.spacing24,
            AppleDesignSystem.spacing12,
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                _AppleBackButton(onPressed: onBackPressed),
                const SizedBox(width: AppleDesignSystem.spacing12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: AppleDesignSystem.typeScaleLargeTitle,
                    fontWeight: AppleDesignSystem.weightBold,
                    letterSpacing: -0.5,
                    color: isDark 
                        ? AppleColors.labelPrimaryDark 
                        : AppleColors.labelPrimary,
                  ),
                ),
              ),
              if (actions != null) ...[
                const SizedBox(width: AppleDesignSystem.spacing16),
                ...actions!.map((action) => Padding(
                  padding: const EdgeInsets.only(left: AppleDesignSystem.spacing8),
                  child: action,
                )),
              ],
            ],
          ),
        ),
        
        // Subtle divider
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isDark ? AppleColors.separatorDark : AppleColors.separator)
                    .withValues(alpha: 0),
                isDark ? AppleColors.separatorDark : AppleColors.separator,
                (isDark ? AppleColors.separatorDark : AppleColors.separator)
                    .withValues(alpha: 0),
              ],
            ),
          ),
        ),
        
        // Page content with smooth scroll physics
        Expanded(
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(
              horizontal: AppleDesignSystem.spacing24,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Apple-styled section header with optional trailing action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onSeeAllPressed;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onSeeAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppleDesignSystem.spacing16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: AppleDesignSystem.typeScaleTitle2,
                    fontWeight: AppleDesignSystem.weightSemiBold,
                    letterSpacing: -0.3,
                    color: isDark 
                        ? AppleColors.labelPrimaryDark 
                        : AppleColors.labelPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppleDesignSystem.spacing4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: AppleDesignSystem.typeScaleSubheadline,
                      color: isDark 
                          ? AppleColors.labelSecondaryDark 
                          : AppleColors.labelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) 
            trailing!
          else if (onSeeAllPressed != null)
            _AppleSeeAllButton(onPressed: onSeeAllPressed!),
        ],
      ),
    );
  }
}

/// Apple-styled back button with SF Symbol style icon
class _AppleBackButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _AppleBackButton({this.onPressed});

  @override
  State<_AppleBackButton> createState() => _AppleBackButtonState();
}

class _AppleBackButtonState extends State<_AppleBackButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed ?? () => Navigator.of(context).pop(),
        child: AnimatedContainer(
          duration: AppleDesignSystem.animationDurationFast,
          curve: AppleDesignSystem.animationCurve,
          padding: const EdgeInsets.all(AppleDesignSystem.spacing8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark 
                    ? AppleColors.systemGray5Dark 
                    : AppleColors.systemGray5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppleDesignSystem.radiusSm,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              Text(
                'Back',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleBody,
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

/// Apple-styled "See All" button with chevron
class _AppleSeeAllButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AppleSeeAllButton({required this.onPressed});

  @override
  State<_AppleSeeAllButton> createState() => _AppleSeeAllButtonState();
}

class _AppleSeeAllButtonState extends State<_AppleSeeAllButton> {
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
        child: AnimatedOpacity(
          duration: AppleDesignSystem.animationDurationFast,
          opacity: _isHovered ? 0.7 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See All',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleSubheadline,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppleDesignSystem.spacing4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}