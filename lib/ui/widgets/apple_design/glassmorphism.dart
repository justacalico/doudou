import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:doudou/ui/theme.dart';

// ============================================
// FROSTED GLASS CONTAINER
// ============================================

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double blurAmount;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final double saturation;
  final Clip clipBehavior;

  const FrostedGlass({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blurAmount = AppleDesignSystem.blurThin,
    this.borderRadius = AppleDesignSystem.radiusMedium,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.5,
    this.padding,
    this.margin,
    this.shadows,
    this.saturation = AppleDesignSystem.saturationDefault,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        backgroundColor ??
        (isDark ? AppleColors.glassDark : AppleColors.glassLight);
    final border =
        borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.4));

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? AppleDesignSystem.shadowMedium(Colors.black),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: borderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================
// LIQUID GLASS CARD
// ============================================

/// A card with liquid glass animation and glassmorphism effect
class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableHoverEffect;
  final bool enablePressEffect;
  final Color? accentColor;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppleDesignSystem.radiusLarge,
    this.padding,
    this.margin,
    this.enableHoverEffect = true,
    this.enablePressEffect = true,
    this.accentColor,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isHovering = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppleDesignSystem.durationFast,
      vsync: this,
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: AppleDesignSystem.hoverScale).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppleDesignSystem.springCurve,
          ),
        );

    _opacityAnimation =
        Tween<double>(begin: 1.0, end: AppleDesignSystem.hoverOpacity).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppleDesignSystem.springCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHoverChanged(bool isHovering) {
    if (!widget.enableHoverEffect) return;
    setState(() {
      _isHovering = isHovering;
    });
    if (isHovering) {
      _controller.forward();
    } else if (!_isPressed) {
      _controller.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enablePressEffect) return;
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enablePressEffect) return;
    setState(() {
      _isPressed = false;
    });
    if (!_isHovering) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.enablePressEffect) return;
    setState(() {
      _isPressed = false;
    });
    if (!_isHovering) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => _handleHoverChanged(true),
      onExit: (_) => _handleHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _isPressed
                ? AppleDesignSystem.pressScale
                : _scaleAnimation.value;
            final opacity = _isPressed
                ? AppleDesignSystem.pressOpacity
                : _opacityAnimation.value;

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  margin: widget.margin,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: [
                      ...AppleDesignSystem.shadowMedium(Colors.black),
                      if (_isHovering)
                        BoxShadow(
                          color: accent.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: AppleDesignSystem.blurThin,
                        sigmaY: AppleDesignSystem.blurThin,
                      ),
                      child: AnimatedContainer(
                        duration: AppleDesignSystem.durationFast,
                        padding: widget.padding,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppleColors.glassDark
                              : AppleColors.glassLight,
                          borderRadius: BorderRadius.circular(
                            widget.borderRadius,
                          ),
                          border: Border.all(
                            color: _isHovering
                                ? accent.withOpacity(0.3)
                                : (isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.white.withOpacity(0.4)),
                            width: _isHovering ? 1.5 : 0.5,
                          ),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================
// VIBRANCY CONTAINER
// ============================================

/// A container that adapts to content behind it with vibrancy effect
class VibrancyContainer extends StatelessWidget {
  final Widget child;
  final VibrancyStyle style;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const VibrancyContainer({
    super.key,
    required this.child,
    this.style = VibrancyStyle.regular,
    this.borderRadius = AppleDesignSystem.radiusMedium,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double blur;
    Color glassColor;

    switch (style) {
      case VibrancyStyle.ultraThin:
        blur = AppleDesignSystem.blurUltraThin;
        glassColor = isDark
            ? AppleColors.glassDarkUltraThin
            : AppleColors.glassLightUltraThin;
        break;
      case VibrancyStyle.thin:
        blur = AppleDesignSystem.blurThin;
        glassColor = isDark
            ? AppleColors.glassDarkThin
            : AppleColors.glassLightThin;
        break;
      case VibrancyStyle.regular:
        blur = AppleDesignSystem.blurRegular;
        glassColor = isDark ? AppleColors.glassDark : AppleColors.glassLight;
        break;
      case VibrancyStyle.thick:
        blur = AppleDesignSystem.blurThick;
        glassColor = isDark
            ? AppleColors.glassDark.withOpacity(0.9)
            : AppleColors.glassLight.withOpacity(0.9);
        break;
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum VibrancyStyle { ultraThin, thin, regular, thick }

// ============================================
// APPLE NAVIGATION BAR
// ============================================

class AppleNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final bool useGlass;
  final double height;
  final Color? backgroundColor;

  const AppleNavigationBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.flexibleSpace,
    this.useGlass = true,
    this.height = 56.0,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        backgroundColor ??
        (isDark
            ? AppleColors.backgroundPrimaryDark
            : AppleColors.backgroundPrimary);

    Widget content = SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppleDesignSystem.spacing12),
              ],
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: AppleTextStyles.headline(
                      color: isDark
                          ? AppleColors.labelPrimaryDark
                          : AppleColors.labelPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );

    if (useGlass) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppleDesignSystem.blurThin,
            sigmaY: AppleDesignSystem.blurThin,
          ),
          child: Container(
            color: bgColor.withOpacity(0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [if (flexibleSpace != null) flexibleSpace!, content],
            ),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [if (flexibleSpace != null) flexibleSpace!, content],
      ),
    );
  }
}

// ============================================
// APPLE TAB BAR
// ============================================

class AppleTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<AppleTabBarItem> items;
  final Color? selectedColor;
  final Color? unselectedColor;

  const AppleTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = selectedColor ?? Theme.of(context).colorScheme.primary;
    final unselected =
        unselectedColor ??
        (isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurRegular,
          sigmaY: AppleDesignSystem.blurRegular,
        ),
        child: Container(
          height: 83, // 49 + safe area
          decoration: BoxDecoration(
            color: isDark
                ? AppleColors.glassDark.withOpacity(0.95)
                : AppleColors.glassLight.withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppleColors.separatorDark
                    : AppleColors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == selectedIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: AppleDesignSystem.durationFast,
                      curve: AppleDesignSystem.springCurve,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? selected : unselected,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style:
                                AppleTextStyles.caption2(
                                  color: isSelected ? selected : unselected,
                                ).copyWith(
                                  fontWeight: isSelected
                                      ? AppleDesignSystem.weightMedium
                                      : AppleDesignSystem.weightRegular,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class AppleTabBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const AppleTabBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

// ============================================
// APPLE SIDEBAR
// ============================================

class AppleSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<AppleSidebarItem> items;
  final Widget? header;
  final Widget? footer;
  final double width;

  const AppleSidebar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    this.header,
    this.footer,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurRegular,
          sigmaY: AppleDesignSystem.blurRegular,
        ),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark
                ? AppleColors.glassDark.withOpacity(0.6)
                : AppleColors.glassLight.withOpacity(0.8),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? AppleColors.separatorDark
                    : AppleColors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              if (header != null) header!,
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppleDesignSystem.spacing8,
                    vertical: AppleDesignSystem.spacing8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = index == selectedIndex;

                    return _AppleSidebarTile(
                      item: item,
                      isSelected: isSelected,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onTap: () => onTap(index),
                    );
                  },
                ),
              ),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleSidebarTile extends StatefulWidget {
  final AppleSidebarItem item;
  final bool isSelected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleSidebarTile({
    required this.item,
    required this.isSelected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AppleSidebarTile> createState() => _AppleSidebarTileState();
}

class _AppleSidebarTileState extends State<_AppleSidebarTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing12,
            vertical: AppleDesignSystem.spacing8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withOpacity(widget.isDark ? 0.24 : 0.12)
                : _isHovering
                ? (widget.isDark
                      ? AppleColors.fillPrimaryDark
                      : AppleColors.fillPrimary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected
                    ? widget.item.activeIcon ?? widget.item.icon
                    : widget.item.icon,
                color: widget.isSelected
                    ? widget.primaryColor
                    : widget.isDark
                    ? AppleColors.labelSecondaryDark
                    : AppleColors.labelSecondary,
                size: 20,
              ),
              const SizedBox(width: AppleDesignSystem.spacing12),
              Expanded(
                child: Text(
                  widget.item.label,
                  style:
                      AppleTextStyles.subheadline(
                        color: widget.isSelected
                            ? widget.primaryColor
                            : widget.isDark
                            ? AppleColors.labelPrimaryDark
                            : AppleColors.labelPrimary,
                      ).copyWith(
                        fontWeight: widget.isSelected
                            ? AppleDesignSystem.weightSemiBold
                            : AppleDesignSystem.weightRegular,
                      ),
                ),
              ),
              if (widget.item.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.item.badge!,
                    style: AppleTextStyles.caption2(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppleSidebarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String? badge;

  const AppleSidebarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badge,
  });
}

// ============================================
// MODAL SHEET
// ============================================

class AppleModalSheet extends StatelessWidget {
  final Widget child;
  final bool showGrabber;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool snap;
  final List<double>? snapSizes;

  const AppleModalSheet({
    super.key,
    required this.child,
    this.showGrabber = true,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.9,
    this.snap = true,
    this.snapSizes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: snap,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppleDesignSystem.radiusXLarge),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppleDesignSystem.blurRegular,
              sigmaY: AppleDesignSystem.blurRegular,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppleColors.glassDark : AppleColors.glassLight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppleDesignSystem.radiusXLarge),
                ),
                boxShadow: AppleDesignSystem.shadowXLarge(Colors.black),
              ),
              child: Column(
                children: [
                  if (showGrabber)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppleColors.systemGray3Dark
                            : AppleColors.systemGray4,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// CONTEXT MENU
// ============================================

class AppleContextMenu extends StatelessWidget {
  final List<AppleContextMenuItem> items;
  final double width;

  const AppleContextMenu({super.key, required this.items, this.width = 220});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurRegular,
          sigmaY: AppleDesignSystem.blurRegular,
        ),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark
                ? AppleColors.elevatedSecondaryDark.withOpacity(0.95)
                : AppleColors.glassLight.withOpacity(0.95),
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
            boxShadow: AppleDesignSystem.shadowLarge(Colors.black),
            border: Border.all(
              color: isDark ? AppleColors.separatorDark : AppleColors.separator,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _AppleContextMenuTile(item: items[i], isDark: isDark),
                if (i < items.length - 1 && items[i].showDivider)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: AppleDesignSystem.spacing12,
                    endIndent: AppleDesignSystem.spacing12,
                    color: isDark
                        ? AppleColors.separatorDark
                        : AppleColors.separator,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleContextMenuTile extends StatefulWidget {
  final AppleContextMenuItem item;
  final bool isDark;

  const _AppleContextMenuTile({required this.item, required this.isDark});

  @override
  State<_AppleContextMenuTile> createState() => _AppleContextMenuTileState();
}

class _AppleContextMenuTileState extends State<_AppleContextMenuTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDestructive = widget.item.isDestructive;
    final color = isDestructive
        ? (widget.isDark ? AppleColors.systemRedDark : AppleColors.systemRed)
        : (widget.isDark
              ? AppleColors.labelPrimaryDark
              : AppleColors.labelPrimary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing12,
            vertical: AppleDesignSystem.spacing8,
          ),
          decoration: BoxDecoration(
            color: _isHovering
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 18, color: color),
                const SizedBox(width: AppleDesignSystem.spacing12),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  style: AppleTextStyles.body(color: color),
                ),
              ),
              if (widget.item.shortcut != null)
                Text(
                  widget.item.shortcut!,
                  style: AppleTextStyles.footnote(
                    color: widget.isDark
                        ? AppleColors.labelTertiaryDark
                        : AppleColors.labelTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppleContextMenuItem {
  final String label;
  final IconData? icon;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showDivider;

  const AppleContextMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isDestructive = false,
    this.showDivider = false,
  });
}

// ============================================
// APPLE BUTTON
// ============================================

class AppleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final AppleButtonStyle style;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const AppleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AppleButtonStyle.filled,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
  });

  @override
  State<AppleButton> createState() => _AppleButtonState();
}

class _AppleButtonState extends State<AppleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppleDesignSystem.durationFast,
      vsync: this,
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: AppleDesignSystem.pressScale).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppleDesignSystem.interactiveCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDisabled = widget.onPressed == null;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (widget.style) {
      case AppleButtonStyle.filled:
        backgroundColor = isDisabled
            ? (isDark ? AppleColors.systemGray4Dark : AppleColors.systemGray4)
            : primaryColor;
        foregroundColor = isDisabled
            ? (isDark
                  ? AppleColors.labelTertiaryDark
                  : AppleColors.labelTertiary)
            : Colors.white;
        break;
      case AppleButtonStyle.gray:
        backgroundColor = isDark
            ? AppleColors.fillSecondaryDark
            : AppleColors.fillSecondary;
        foregroundColor = isDisabled
            ? (isDark
                  ? AppleColors.labelTertiaryDark
                  : AppleColors.labelTertiary)
            : primaryColor;
        break;
      case AppleButtonStyle.tinted:
        backgroundColor = primaryColor.withOpacity(isDark ? 0.24 : 0.15);
        foregroundColor = isDisabled
            ? (isDark
                  ? AppleColors.labelTertiaryDark
                  : AppleColors.labelTertiary)
            : primaryColor;
        break;
      case AppleButtonStyle.plain:
        backgroundColor = Colors.transparent;
        foregroundColor = isDisabled
            ? (isDark
                  ? AppleColors.labelTertiaryDark
                  : AppleColors.labelTertiary)
            : primaryColor;
        break;
      case AppleButtonStyle.bordered:
        backgroundColor = Colors.transparent;
        foregroundColor = isDisabled
            ? (isDark
                  ? AppleColors.labelTertiaryDark
                  : AppleColors.labelTertiary)
            : primaryColor;
        border = Border.all(
          color: isDisabled
              ? (isDark ? AppleColors.separatorDark : AppleColors.separator)
              : primaryColor,
          width: 1,
        );
        break;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedOpacity(
              duration: AppleDesignSystem.durationFast,
              opacity: _isPressed ? AppleDesignSystem.pressOpacity : 1.0,
              child: Container(
                width: widget.width,
                height: widget.height ?? 44,
                padding:
                    widget.padding ??
                    const EdgeInsets.symmetric(
                      horizontal: AppleDesignSystem.spacing20,
                      vertical: AppleDesignSystem.spacing12,
                    ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(
                    AppleDesignSystem.radiusMedium,
                  ),
                  border: border,
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(foregroundColor),
                          ),
                        )
                      : DefaultTextStyle(
                          style: AppleTextStyles.headline(
                            color: foregroundColor,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              color: foregroundColor,
                              size: 20,
                            ),
                            child: widget.child,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum AppleButtonStyle { filled, gray, tinted, plain, bordered }

// ============================================
// APPLE LIST TILE
// ============================================

class AppleListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const AppleListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  State<AppleListTile> createState() => _AppleListTileState();
}

class _AppleListTileState extends State<AppleListTile> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            vertical: AppleDesignSystem.spacing12,
          ),
          decoration: BoxDecoration(
            color: _isPressed
                ? (isDark
                      ? AppleColors.fillSecondaryDark
                      : AppleColors.fillSecondary)
                : _isHovering
                ? (isDark
                      ? AppleColors.fillTertiaryDark
                      : AppleColors.fillTertiary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: AppleDesignSystem.spacing12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppleTextStyles.body(
                        color: isDark
                            ? AppleColors.labelPrimaryDark
                            : AppleColors.labelPrimary,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: AppleTextStyles.footnote(
                          color: isDark
                              ? AppleColors.labelSecondaryDark
                              : AppleColors.labelSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
              if (widget.showChevron && widget.onTap != null) ...[
                const SizedBox(width: AppleDesignSystem.spacing8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: isDark
                      ? AppleColors.labelTertiaryDark
                      : AppleColors.labelTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
