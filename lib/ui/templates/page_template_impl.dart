import 'package:flutter/material.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/theme.dart';

/// Shared page scaffold used across all top-level and detail pages.
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
    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.primary.withValues(alpha: 0.18),
        theme.colorScheme.primary.withValues(alpha: 0.07),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingSm,
          ),
          padding: const EdgeInsets.fromLTRB(
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingLg,
            DesktopTheme.spacingMd,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
            border: Border.all(color: DesktopTheme.glassBorder),
            color: DesktopTheme.backgroundTertiary.withValues(alpha: 0.72),
            gradient: showGradientHeader ? headerGradient : null,
            boxShadow: DesktopTheme.shadowMd,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton) ...[
                        _ModernBackButton(onPressed: onBackPressed),
                        const SizedBox(width: DesktopTheme.spacingMd),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.headlineMedium?.copyWith(
                                color: DesktopTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                height: 1.15,
                              ) ??
                              TextStyle(
                                fontSize: AppTokens.typeScaleTitle1,
                                fontWeight: FontWeight.w700,
                                color: DesktopTheme.textPrimary,
                                letterSpacing: -0.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DesktopTheme.spacingSm),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: DesktopTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (actions != null && actions!.isNotEmpty) ...[
                    SizedBox(
                      height: isNarrow
                          ? DesktopTheme.spacingMd
                          : DesktopTheme.spacingLg,
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Row(
                        children: actions!
                            .map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(
                                  right: DesktopTheme.spacingSm,
                                ),
                                child: action,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.fromLTRB(
                  DesktopTheme.spacingLg,
                  DesktopTheme.spacingSm,
                  DesktopTheme.spacingLg,
                  0,
                ),
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

    final titleWidget = useGradient
        ? DesktopGradientText(
            text: title,
            style:
                theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ) ??
                const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.55),
            ],
          )
        : Text(
            title,
            style:
                theme.textTheme.titleLarge?.copyWith(
                  color: DesktopTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ) ??
                TextStyle(
                  fontSize: AppTokens.typeScaleTitle2,
                  fontWeight: FontWeight.w700,
                  color: DesktopTheme.textPrimary,
                ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesktopTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                if (subtitle != null) ...[
                  const SizedBox(height: DesktopTheme.spacingXs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
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

class _ModernBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ModernBackButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(AppLocalizations.of(context).back),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusRound),
          ),
        ),
      ),
    );
  }
}

class _ModernSeeAllButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ModernSeeAllButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.east_rounded, size: 16),
      label: Text(AppLocalizations.of(context).viewAll),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickAccessCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < 190;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
              border: Border.all(color: DesktopTheme.glassBorder),
              color: DesktopTheme.backgroundTertiary.withValues(alpha: 0.75),
              boxShadow: DesktopTheme.shadowSm,
            ),
            child: iconOnly
                ? Tooltip(
                    message: title,
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DesktopTheme.textPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: DesktopTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class MusicListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const MusicListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.trailing,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          border: Border.all(color: DesktopTheme.glassBorder),
          color: DesktopTheme.backgroundTertiary.withValues(alpha: 0.68),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: DesktopTheme.backgroundElevated,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.music_note_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: theme.colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: DesktopTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DesktopTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
