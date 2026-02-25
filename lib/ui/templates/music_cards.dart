import 'package:flutter/material.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/universal_image.dart';

class MusicCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double size;
  final bool showPlayOverlay;
  final IconData? placeholderIcon;

  const MusicCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
    this.size = 180,
    this.showPlayOverlay = true,
    this.placeholderIcon,
  });

  @override
  State<MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _pressed ? 0.98 : (_hovered ? 1.015 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          scale: scale,
          child: SizedBox(
            width: widget.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _artwork(theme),
                const SizedBox(height: DesktopTheme.spacingSm),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: DesktopTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
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
        ),
      ),
    );
  }

  Widget _artwork(ThemeData theme) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: DesktopTheme.durationFast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          border: Border.all(
            color: _hovered
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : DesktopTheme.glassBorder,
          ),
          boxShadow: _hovered
              ? [
                  ...DesktopTheme.shadowMd,
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : DesktopTheme.shadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.imageUrl != null)
                buildSmartImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: () => _placeholder(theme),
                )
              else
                _placeholder(theme),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: _hovered ? 0.34 : 0.2),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.showPlayOverlay)
                Center(
                  child: AnimatedOpacity(
                    duration: DesktopTheme.durationFast,
                    opacity: _hovered ? 1 : 0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        boxShadow: DesktopTheme.shadowGlow(theme.colorScheme.primary),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: DesktopTheme.backgroundElevated,
      child: Center(
        child: Icon(
          widget.placeholderIcon ?? Icons.music_note_rounded,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
