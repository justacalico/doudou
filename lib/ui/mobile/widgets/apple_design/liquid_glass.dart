import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apple_theme.dart';

// ============================================
// CACHED IMAGE FILTERS (Performance optimization)
// ============================================

/// Pre-cached ImageFilter instances to avoid recreation on every build
class _CachedBlurFilters {
  static final Map<double, ImageFilter> _cache = {};
  
  static ImageFilter get(double sigma) {
    return _cache.putIfAbsent(
      sigma,
      () => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  }
  
  // Common blur values pre-cached
  static final blur30 = get(30);
}

// ============================================
// LIQUID GLASS MATERIAL
// ============================================

class LiquidGlassMaterial extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? tintColor;
  final double tintOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showBorder;
  final double borderOpacity;
  final List<BoxShadow>? shadows;

  const LiquidGlassMaterial({
    super.key,
    required this.child,
    this.blur = 25,
    this.tintColor,
    this.tintOpacity = 0.1,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.showBorder = true,
    this.borderOpacity = 0.2,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final baseTint = tintColor ?? (isDark ? Colors.white : Colors.black);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: _CachedBlurFilters.get(blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                color: baseTint.withOpacity(tintOpacity),
                border: showBorder
                    ? Border.all(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(
                          borderOpacity,
                        ),
                        width: 0.5,
                      )
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(isDark ? 0.08 : 0.5),
                    Colors.white.withOpacity(isDark ? 0.03 : 0.2),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS NAV BAR
// ============================================

class LiquidGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidGlassNavItem> items;
  final Color? accentColor;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final accent = accentColor ?? AppleColors.systemPink;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: _CachedBlurFilters.blur30,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: (isDark ? Colors.white : Colors.black).withOpacity(
                  isDark ? 0.12 : 0.06,
                ),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Trigger iOS-style haptic feedback on tap
                        HapticFeedback.selectionClick();
                        onTap(index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: _NavBarItemWidget(
                        item: item,
                        isSelected: isSelected,
                        accent: accent,
                        isDark: isDark,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemWidget extends StatefulWidget {
  final LiquidGlassNavItem item;
  final bool isSelected;
  final Color accent;
  final bool isDark;

  const _NavBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.accent,
    required this.isDark,
  });

  @override
  State<_NavBarItemWidget> createState() => _NavBarItemWidgetState();
}

class _NavBarItemWidgetState extends State<_NavBarItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: widget.isSelected
                  ? widget.accent.withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.isSelected ? widget.item.activeIcon : widget.item.icon,
              size: 24,
              color: widget.isSelected
                  ? widget.accent
                  : (widget.isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: AppleDesignSystem.fontFamily,
              fontSize: 10,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? widget.accent
                  : (widget.isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.4)),
            ),
            child: Text(widget.item.label),
          ),
        ],
      ),
    );
  }
}

class LiquidGlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const LiquidGlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ============================================
// LIQUID GLASS MINI PLAYER
// ============================================

class LiquidGlassMiniPlayer extends StatelessWidget {
  final Widget albumArt;
  final String title;
  final String? artist;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final bool hasNext;

  const LiquidGlassMiniPlayer({
    super.key,
    required this.albumArt,
    required this.title,
    this.artist,
    this.isPlaying = false,
    this.isLoading = false,
    this.onTap,
    this.onPlayPause,
    this.onNext,
    this.hasNext = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: (isDark ? Colors.white : Colors.black).withOpacity(
                  isDark ? 0.15 : 0.08,
                ),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.12,
                  ),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: albumArt,
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppleDesignSystem.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (artist != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              artist!,
                              style: TextStyle(
                                fontFamily: AppleDesignSystem.fontFamily,
                                fontSize: 13,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiquidGlassIconButton(
                          icon: isLoading
                              ? null
                              : (isPlaying
                                    ? CupertinoIcons.pause_fill
                                    : CupertinoIcons.play_fill),
                          isLoading: isLoading,
                          onTap: onPlayPause,
                          size: 32,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 4),
                        _LiquidGlassIconButton(
                          icon: CupertinoIcons.forward_fill,
                          onTap: hasNext ? onNext : null,
                          size: 32,
                          isDark: isDark,
                          disabled: !hasNext,
                        ),
                      ],
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

class _LiquidGlassIconButton extends StatefulWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final double size;
  final bool isDark;
  final bool isLoading;
  final bool disabled;

  const _LiquidGlassIconButton({
    this.icon,
    this.onTap,
    required this.size,
    required this.isDark,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  State<_LiquidGlassIconButton> createState() => _LiquidGlassIconButtonState();
}

class _LiquidGlassIconButtonState extends State<_LiquidGlassIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => _controller.forward(),
      onTapUp: widget.disabled ? null : (_) => _controller.reverse(),
      onTapCancel: widget.disabled ? null : () => _controller.reverse(),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: widget.isLoading
                ? CupertinoActivityIndicator(
                    color: widget.isDark ? Colors.white : Colors.black,
                  )
                : Icon(
                    widget.icon,
                    size: widget.size * 0.7,
                    color: widget.disabled
                        ? (widget.isDark ? Colors.white : Colors.black)
                              .withOpacity(0.3)
                        : (widget.isDark ? Colors.white : Colors.black),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS SEARCH BAR
// ============================================

class LiquidGlassSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const LiquidGlassSearchBar({
    super.key,
    this.controller,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (isDark ? Colors.white : Colors.black).withOpacity(
              isDark ? 0.12 : 0.06,
            ),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                CupertinoIcons.search,
                size: 20,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  placeholder: placeholder,
                  placeholderStyle: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 16,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.4,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  padding: EdgeInsets.zero,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
              ),
              if (controller?.text.isNotEmpty ?? false) ...[
                GestureDetector(
                  onTap: () {
                    controller?.clear();
                    onClear?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS SECTION HEADER
// ============================================

class LiquidGlassSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const LiquidGlassSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 15,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                'See All',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppleColors.systemPink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// LIQUID GLASS ALBUM CARD
// ============================================

class LiquidGlassAlbumCard extends StatefulWidget {
  final Widget image;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double width;

  const LiquidGlassAlbumCard({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.onTap,
    this.width = 160,
  });

  @override
  State<LiquidGlassAlbumCard> createState() => _LiquidGlassAlbumCardState();
}

class _LiquidGlassAlbumCardState extends State<LiquidGlassAlbumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: widget.width,
                height: widget.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: widget.image,
                ),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS LIST TILE
// ============================================

class LiquidGlassListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? accentColor;

  const LiquidGlassListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.accentColor,
  });

  @override
  State<LiquidGlassListTile> createState() => _LiquidGlassListTileState();
}

class _LiquidGlassListTileState extends State<LiquidGlassListTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? (isDark ? Colors.white : Colors.black).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontFamily: AppleDesignSystem.fontFamily,
                        fontSize: 14,
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS CHIP
// ============================================

class LiquidGlassChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? accentColor;

  const LiquidGlassChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.accentColor,
  });

  @override
  State<LiquidGlassChip> createState() => _LiquidGlassChipState();
}

class _LiquidGlassChipState extends State<LiquidGlassChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppleColors.systemPink;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.icon != null ? 14 : 18,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isSelected
                ? accent.withOpacity(0.2)
                : (isDark ? Colors.white : Colors.black).withOpacity(
                    isDark ? 0.1 : 0.06,
                  ),
            border: Border.all(
              color: widget.isSelected
                  ? accent.withOpacity(0.5)
                  : (isDark ? Colors.white : Colors.black).withOpacity(0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.isSelected
                      ? accent
                      : (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 14,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? accent
                      : (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS FLOATING ACTION BUTTON
// ============================================

class LiquidGlassFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;
  final String? tooltip;

  const LiquidGlassFAB({
    super.key,
    required this.icon,
    this.onTap,
    this.accentColor,
    this.tooltip,
  });

  @override
  State<LiquidGlassFAB> createState() => _LiquidGlassFABState();
}

class _LiquidGlassFABState extends State<LiquidGlassFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppleColors.systemPink;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent.withOpacity(0.8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS PROGRESS BAR
// ============================================

class LiquidGlassProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? accentColor;
  final Color? backgroundColor;

  const LiquidGlassProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.accentColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final accent = accentColor ?? AppleColors.systemPink;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color:
            backgroundColor ??
            (isDark ? Colors.white : Colors.black).withOpacity(0.15),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.8)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// ANIMATED GRADIENT BACKGROUND
// ============================================

/// Animated mesh gradient background for screens
class LiquidGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animate;

  const LiquidGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.animate = true,
  });

  @override
  State<LiquidGradientBackground> createState() =>
      _LiquidGradientBackgroundState();
}

class _LiquidGradientBackgroundState extends State<LiquidGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final defaultColors = isDark
        ? [
            const Color(0xFF0D0D0D),
            const Color(0xFF1A0A1A),
            const Color(0xFF0A1A1A),
          ]
        : [
            const Color(0xFFFAFAFA),
            const Color(0xFFF5F0F8),
            const Color(0xFFF0F5F8),
          ];

    final colors = widget.colors ?? defaultColors;

    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),

        // Animated orbs
        if (widget.animate)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              return CustomPaint(
                size: Size.infinite,
                painter: _OrbPainter(progress: progress, isDark: isDark),
              );
            },
          ),

        // Content
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _OrbPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(
        baseX: 0.2,
        baseY: 0.3,
        radius: size.width * 0.4,
        color: (isDark
            ? AppleColors.systemPink
            : AppleColors.systemPink.withOpacity(0.3)),
        phaseX: 0,
        phaseY: 0.5,
      ),
      _Orb(
        baseX: 0.8,
        baseY: 0.5,
        radius: size.width * 0.35,
        color: (isDark
            ? AppleColors.systemPurple
            : AppleColors.systemPurple.withOpacity(0.3)),
        phaseX: 0.3,
        phaseY: 0.8,
      ),
      _Orb(
        baseX: 0.4,
        baseY: 0.8,
        radius: size.width * 0.3,
        color: (isDark
            ? AppleColors.systemBlue
            : AppleColors.systemBlue.withOpacity(0.3)),
        phaseX: 0.7,
        phaseY: 0.2,
      ),
    ];

    for (final orb in orbs) {
      final x =
          size.width *
          (orb.baseX + math.sin((progress + orb.phaseX) * math.pi * 2) * 0.1);
      final y =
          size.height *
          (orb.baseY + math.cos((progress + orb.phaseY) * math.pi * 2) * 0.1);

      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                orb.color.withOpacity(isDark ? 0.15 : 0.1),
                orb.color.withOpacity(0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y), radius: orb.radius),
            );

      canvas.drawCircle(Offset(x, y), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Orb {
  final double baseX;
  final double baseY;
  final double radius;
  final Color color;
  final double phaseX;
  final double phaseY;

  _Orb({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.color,
    required this.phaseX,
    required this.phaseY,
  });
}
