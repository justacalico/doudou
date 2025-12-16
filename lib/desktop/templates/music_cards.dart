import 'dart:ui';
import 'package:flutter/material.dart';
import 'desktop_theme.dart';

/// Modern glass-styled music card with hover effects and glow
class MusicCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double size;
  final bool showPlayOverlay;

  const MusicCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
    this.size = 180,
    this.showPlayOverlay = true,
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
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.97 : _isHovering ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          child: SizedBox(
            width: widget.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Album art container
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                      boxShadow: _isHovering
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              ...DesktopTheme.shadowMd,
                            ]
                          : DesktopTheme.shadowSm,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image or placeholder
                          widget.imageUrl != null
                              ? Image.network(
                                  widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder(theme);
                                  },
                                )
                              : _buildPlaceholder(theme),
                          
                          // Gradient overlay on hover
                          AnimatedOpacity(
                            duration: DesktopTheme.durationFast,
                            opacity: _isHovering ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Play button overlay
                          if (widget.showPlayOverlay)
                            AnimatedOpacity(
                              duration: DesktopTheme.durationFast,
                              opacity: _isHovering ? 1.0 : 0.0,
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: DesktopTheme.shadowGlow(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: DesktopTheme.spacingSm),
                
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DesktopTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 2),
                
                // Subtitle
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: DesktopTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DesktopTheme.backgroundElevated,
            DesktopTheme.backgroundTertiary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 48,
          color: DesktopTheme.textMuted,
        ),
      ),
    );
  }
}

/// Modern list tile with hover effects
class MusicListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  final bool showPlayOnHover;

  const MusicListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
    this.leading,
    this.showPlayOnHover = true,
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
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isPressed
                ? DesktopTheme.glassOverlay
                : _isHovering
                    ? DesktopTheme.glassHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            border: _isHovering ? Border.all(
              color: DesktopTheme.glassBorder,
              width: 1,
            ) : null,
          ),
          child: Row(
            children: [
              // Leading widget or album art
              if (widget.leading != null)
                widget.leading!
              else
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: DesktopTheme.backgroundElevated,
                        borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                        boxShadow: DesktopTheme.shadowSm,
                      ),
                      child: widget.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                              child: Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note_rounded,
                                    color: DesktopTheme.textMuted,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note_rounded,
                              color: DesktopTheme.textMuted,
                            ),
                    ),
                    // Play overlay on hover
                    if (widget.showPlayOnHover)
                      AnimatedOpacity(
                        duration: DesktopTheme.durationFast,
                        opacity: _isHovering ? 1.0 : 0.0,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              
              const SizedBox(width: DesktopTheme.spacingMd),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isHovering
                            ? theme.colorScheme.primary
                            : DesktopTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              if (widget.trailing != null) ...[
                const SizedBox(width: DesktopTheme.spacingSm),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Large featured card with blur background
class FeaturedMusicCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double height;

  const FeaturedMusicCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.height = 200,
  });

  @override
  State<FeaturedMusicCard> createState() => _FeaturedMusicCardState();
}

class _FeaturedMusicCardState extends State<FeaturedMusicCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          height: widget.height,
          transform: Matrix4.identity()
            ..scale(_isHovering ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
            boxShadow: _isHovering
                ? DesktopTheme.shadowLg
                : DesktopTheme.shadowMd,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                widget.imageUrl != null
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: DesktopTheme.accentGradientPurple,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: DesktopTheme.accentGradientPurple,
                          ),
                        ),
                      ),
                
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Positioned(
                  left: DesktopTheme.spacingLg,
                  right: DesktopTheme.spacingLg,
                  bottom: DesktopTheme.spacingLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        duration: DesktopTheme.durationFast,
                        opacity: _isHovering ? 1.0 : 0.7,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: DesktopTheme.shadowGlow(
                              theme.colorScheme.primary,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick access card with icon
class QuickAccessCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const QuickAccessCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<QuickAccessCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          transform: Matrix4.identity()
            ..scale(_isHovering ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: DesktopTheme.blurMedium,
                sigmaY: DesktopTheme.blurMedium,
              ),
              child: Container(
                padding: const EdgeInsets.all(DesktopTheme.spacingLg),
                decoration: BoxDecoration(
                  color: DesktopTheme.glassSurface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                  border: Border.all(
                    color: _isHovering
                        ? widget.color.withOpacity(0.3)
                        : DesktopTheme.glassBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: DesktopTheme.spacingMd),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textSecondary,
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
}