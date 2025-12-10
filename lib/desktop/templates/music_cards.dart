import 'package:flutter/material.dart';
import '../../widgets/apple_design/apple_theme.dart';

/// Apple-styled music card with hover effects and glassmorphism
class MusicCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double size;

  const MusicCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
    this.size = 160,
  });

  @override
  State<MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed 
              ? AppleDesignSystem.pressScale 
              : _isHovering 
                  ? AppleDesignSystem.hoverScale 
                  : 1.0,
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          child: AnimatedOpacity(
            opacity: _isPressed ? AppleDesignSystem.pressOpacity : 1.0,
            duration: AppleDesignSystem.durationFast,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
                  color: isDark 
                      ? AppleColors.elevatedPrimaryDark 
                      : AppleColors.backgroundTertiary,
                  boxShadow: _isHovering
                      ? AppleDesignSystem.shadowMedium(Colors.black)
                      : AppleDesignSystem.shadowSmall(Colors.black),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image/Album art with subtle overlay on hover
                    Expanded(
                      flex: 7,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? AppleColors.elevatedSecondaryDark 
                                  : AppleColors.systemGray6,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppleDesignSystem.radiusMedium),
                              ),
                            ),
                            child: widget.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(AppleDesignSystem.radiusMedium),
                                    ),
                                    child: Image.network(
                                      widget.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildPlaceholder(theme, isDark);
                                      },
                                    ),
                                  )
                                : _buildPlaceholder(theme, isDark),
                          ),
                          // Play overlay on hover
                          AnimatedOpacity(
                            opacity: _isHovering ? 1.0 : 0.0,
                            duration: AppleDesignSystem.durationFast,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppleDesignSystem.radiusMedium),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.4),
                                  ],
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppleDesignSystem.spacing8),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: AppleDesignSystem.shadowSmall(
                                        theme.colorScheme.primary,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Text content
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(AppleDesignSystem.spacing12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: AppleTextStyles.subheadline(
                                  color: isDark 
                                      ? AppleColors.labelPrimaryDark 
                                      : AppleColors.labelPrimary,
                                ).copyWith(
                                  fontWeight: AppleDesignSystem.weightSemiBold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Flexible(
                              child: Text(
                                widget.subtitle,
                                style: AppleTextStyles.footnote(
                                  color: isDark 
                                      ? AppleColors.labelSecondaryDark 
                                      : AppleColors.labelSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, bool isDark) {
    return Center(
      child: Icon(
        Icons.music_note,
        size: 48,
        color: isDark 
            ? AppleColors.labelTertiaryDark 
            : AppleColors.labelTertiary,
      ),
    );
  }
}

/// Apple-styled list tile with hover effects
class MusicListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;

  const MusicListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
  });

  @override
  State<MusicListTile> createState() => _MusicListTileState();
}

class _MusicListTileState extends State<MusicListTile> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing8,
          ),
          decoration: BoxDecoration(
            color: _isPressed
                ? (isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary)
                : _isHovering
                    ? (isDark ? AppleColors.fillTertiaryDark : AppleColors.fillTertiary)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          ),
          child: Row(
            children: [
              // Album art
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppleColors.elevatedSecondaryDark 
                      : AppleColors.systemGray6,
                  borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
                  boxShadow: AppleDesignSystem.shadowSmall(Colors.black),
                ),
                child: widget.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
                        child: Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.music_note,
                              color: isDark 
                                  ? AppleColors.labelTertiaryDark 
                                  : AppleColors.labelTertiary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: isDark 
                            ? AppleColors.labelTertiaryDark 
                            : AppleColors.labelTertiary,
                      ),
              ),
              const SizedBox(width: AppleDesignSystem.spacing12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: AppleTextStyles.body(
                        color: isDark 
                            ? AppleColors.labelPrimaryDark 
                            : AppleColors.labelPrimary,
                      ).copyWith(
                        fontWeight: AppleDesignSystem.weightMedium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppleTextStyles.footnote(
                        color: isDark 
                            ? AppleColors.labelSecondaryDark 
                            : AppleColors.labelSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}