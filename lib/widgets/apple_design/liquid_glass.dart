import 'dart:ui';
import 'package:flutter/material.dart';

/// Liquid Glass gradient background widget - provides a modern glassmorphic effect
class LiquidGradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animated;
  
  const LiquidGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.animated = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final gradientColors = colors ?? (isDark 
      ? [
          const Color(0xFF0D0D0D),
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F3460),
        ]
      : [
          const Color(0xFFF8F9FA),
          const Color(0xFFE9ECEF),
          const Color(0xFFDEE2E6),
          const Color(0xFFCED4DA),
        ]);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: child,
    );
  }
}

/// Liquid Glass Card - a card with glassmorphic effect
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Border? border;
  
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.blur = 20,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (backgroundColor ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.12),
                  (backgroundColor ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: border ?? Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Button - a button with glassmorphic effect
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double blur;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  
  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.blur = 10,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
  });
  
  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isPressed = false;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blur,
              sigmaY: widget.blur,
            ),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (widget.backgroundColor ?? (isDark ? Colors.white : Colors.black))
                        .withOpacity(_isPressed ? 0.2 : 0.15),
                    (widget.backgroundColor ?? (isDark ? Colors.white : Colors.black))
                        .withOpacity(_isPressed ? 0.1 : 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass AppBar - an app bar with glassmorphic effect
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final double blur;
  final double height;
  
  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.blur = 20,
    this.height = 56,
  });
  
  @override
  Size get preferredSize => Size.fromHeight(height);
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                (isDark ? Colors.black : Colors.white).withOpacity(0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: leading!,
                ),
              Expanded(
                child: title != null
                    ? Center(child: title!)
                    : const SizedBox(),
              ),
              if (actions != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass List Tile - a list tile with glassmorphic effect
class LiquidGlassListTile extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double blur;
  final EdgeInsets? padding;
  
  const LiquidGlassListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.blur = 10,
    this.padding,
  });
  
  @override
  State<LiquidGlassListTile> createState() => _LiquidGlassListTileState();
}

class _LiquidGlassListTileState extends State<LiquidGlassListTile> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding ?? const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? Colors.white : Colors.black).withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (widget.leading != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: widget.leading!,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null) widget.title!,
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: widget.subtitle!,
                      ),
                  ],
                ),
              ),
              if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: widget.trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
