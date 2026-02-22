import 'dart:ui';
import 'package:flutter/material.dart';

/// Modern Desktop Theme System
/// Combines iOS 26 Liquid Glass aesthetics with desktop-optimized layouts

class DesktopTheme {
  DesktopTheme._();

  static const Color _oledBlack = Color(0xFF000000);

  static bool _isDark = true;
  static bool _isOled = false;

  static void updateBrightness(Brightness brightness, {bool oled = false}) {
    _isDark = brightness == Brightness.dark;
    _isOled = oled && _isDark;
  }

  static bool get isOled => _isOled;

  // ============================================
  // COLOR PALETTE - Dual Mode (+ OLED)
  // ============================================

  /// Deep background colors (Gemini redesign: dark gray; OLED = pure black)
  static const Color backgroundDeepDark = Color(0xFF0A0A0C);
  static const Color backgroundDeepLight = Color(0xFFF5F6FA);
  static Color get backgroundDeep =>
      _isOled ? _oledBlack : (_isDark ? backgroundDeepDark : backgroundDeepLight);

  /// Sidebar background (slightly lighter than deep for dark mode)
  static const Color backgroundSidebarDark = Color(0xFF0E0E11);
  static Color get backgroundSidebar =>
      _isOled ? _oledBlack : (_isDark ? backgroundSidebarDark : backgroundPrimaryLight);

  static const Color backgroundPrimaryDark = Color(0xFF121216);
  static const Color backgroundPrimaryLight = Color(0xFFFFFFFF);
  static Color get backgroundPrimary =>
      _isOled ? _oledBlack : (_isDark ? backgroundPrimaryDark : backgroundPrimaryLight);

  static const Color backgroundSecondaryDark = Color(0xFF121216);
  static const Color backgroundSecondaryLight = Color(0xFFF0F1F5);
  static Color get backgroundSecondary =>
      _isOled ? _oledBlack : (_isDark ? backgroundSecondaryDark : backgroundSecondaryLight);

  static const Color backgroundTertiaryDark = Color(0xFF16161C);
  static const Color backgroundTertiaryLight = Color(0xFFE6E7EE);
  static Color get backgroundTertiary =>
      _isOled ? _oledBlack : (_isDark ? backgroundTertiaryDark : backgroundTertiaryLight);

  static const Color backgroundElevatedDark = Color(0xFF16161C);
  static const Color backgroundElevatedLight = Color(0xFFEEF0F6);
  static Color get backgroundElevated =>
      _isOled ? _oledBlack : (_isDark ? backgroundElevatedDark : backgroundElevatedLight);

  /// Nav active/hover (Gemini: white/10, white/5)
  static const Color sidebarActiveDark = Color(0x1AFFFFFF);
  static const Color sidebarHoverDark = Color(0x0DFFFFFF);
  static Color get sidebarActive =>
      _isDark ? sidebarActiveDark : const Color(0x1A000000);
  static Color get sidebarHover =>
      _isDark ? sidebarHoverDark : const Color(0x0D000000);

  /// Glass surface colors
  static const Color glassSurfaceDark = Color(0xFF121216);
  static const Color glassSurfaceLight = Color(0xFFFFFFFF);
  static Color get glassSurface =>
      _isOled ? _oledBlack : (_isDark ? glassSurfaceDark : glassSurfaceLight);

  static const Color glassOverlayDark = Color(0x15FFFFFF);
  static const Color glassOverlayLight = Color(0x15000000);
  static Color get glassOverlay =>
      _isDark ? glassOverlayDark : glassOverlayLight;

  static const Color glassBorderDark = Color(0x0DFFFFFF); // white/5 (Gemini)
  static const Color glassBorderLight = Color(0x1A000000);
  static Color get glassBorder => _isDark ? glassBorderDark : glassBorderLight;

  static const Color glassHighlightDark = Color(0x08FFFFFF);
  static const Color glassHighlightLight = Color(0x0D000000);
  static Color get glassHighlight =>
      _isDark ? glassHighlightDark : glassHighlightLight;

  /// Accent gradients
  static const List<Color> accentGradientPurple = [
    Color(0xFF8B5CF6),
    Color(0xFFD946EF),
  ];
  static const List<Color> accentGradientPink = [
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
  ];
  static const List<Color> accentGradientBlue = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
  ];

  /// Text colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F0F12);
  static Color get textPrimary =>
      _isDark ? textPrimaryDark : textPrimaryLight;

  static const Color textSecondaryDark = Color(0xB3FFFFFF);
  static const Color textSecondaryLight = Color(0x990F0F12);
  static Color get textSecondary =>
      _isDark ? textSecondaryDark : textSecondaryLight;

  static const Color textTertiaryDark = Color(0x66FFFFFF);
  static const Color textTertiaryLight = Color(0x660F0F12);
  static Color get textTertiary =>
      _isDark ? textTertiaryDark : textTertiaryLight;

  static const Color textMutedDark = Color(0x33FFFFFF);
  static const Color textMutedLight = Color(0x330F0F12);
  static Color get textMuted => _isDark ? textMutedDark : textMutedLight;

  /// Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Vibrant UI colors
  static const Color playButtonGreen = Color(0xFF1DB954);
  static const Color heartRed = Color(0xFFEF4444);
  static const Color shufflePurple = Color(0xFF8B5CF6);
  static const Color repeatBlue = Color(0xFF3B82F6);
  static const Color accentPrimary = Color(0xFF8B5CF6);

  /// Pre-built gradient for accent styling
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ============================================
  // SIZING & SPACING
  // ============================================

  static const double sidebarWidth = 260.0;
  static const double sidebarCollapsedWidth = 72.0;
  static const double playerBarHeight = 96.0;
  static const double headerHeight = 72.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusRound = 100.0;

  // ============================================
  // BLUR VALUES
  // ============================================

  static const double blurLight = 10.0;
  static const double blurMedium = 20.0;
  static const double blurHeavy = 40.0;
  static const double blurExtreme = 60.0;

  // ============================================
  // ANIMATION
  // ============================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Curve curveSpring = Curves.easeOutCubic;
  static const Curve curveSnappy = Cubic(0.2, 0.0, 0.0, 1.0);

  // ============================================
  // SHADOW PRESETS
  // ============================================

  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: color.withOpacity(0.2),
      blurRadius: 48,
      offset: const Offset(0, 8),
    ),
  ];
}

// ============================================
// LIQUID GLASS WIDGETS FOR DESKTOP
// ============================================

/// Frosted glass container with customizable blur and tint
class DesktopGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const DesktopGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.blur = DesktopTheme.blurMedium,
    this.borderRadius = DesktopTheme.radiusMd,
    this.backgroundColor,
    this.showBorder = true,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? DesktopTheme.shadowMd,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color:
                  backgroundColor ?? DesktopTheme.glassSurface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border.all(color: DesktopTheme.glassBorder, width: 1)
                  : null,
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [DesktopTheme.glassHighlight, Colors.transparent],
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Hover-reactive glass button with glow effect
class DesktopGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool filled;
  final bool showGlow;

  const DesktopGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.accentColor,
    this.borderRadius = DesktopTheme.radiusMd,
    this.padding,
    this.filled = false,
    this.showGlow = true,
  });

  @override
  State<DesktopGlassButton> createState() => _DesktopGlassButtonState();
}

class _DesktopGlassButtonState extends State<DesktopGlassButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final isEnabled = widget.onPressed != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: DesktopTheme.spacingMd,
                vertical: DesktopTheme.spacingSm,
              ),
          transform: Matrix4.identity()
            ..scale(
              _isPressed
                  ? 0.97
                  : _isHovered
                  ? 1.02
                  : 1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: widget.filled
                ? (isEnabled ? accent : accent.withOpacity(0.5))
                : (_isHovered ? DesktopTheme.glassOverlay : Colors.transparent),
            border: widget.filled
                ? null
                : Border.all(
                    color: _isHovered
                        ? accent.withOpacity(0.5)
                        : DesktopTheme.glassBorder,
                    width: 1,
                  ),
            boxShadow: widget.showGlow && _isHovered && widget.filled
                ? DesktopTheme.shadowGlow(accent)
                : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.filled
                  ? Colors.white
                  : (isEnabled
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textMuted),
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: widget.filled
                    ? Colors.white
                    : (isEnabled
                          ? DesktopTheme.textPrimary
                          : DesktopTheme.textMuted),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated play button with pulse effect
class DesktopPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback? onPressed;
  final double size;
  final Color? accentColor;

  const DesktopPlayButton({
    super.key,
    required this.isPlaying,
    this.isBuffering = false,
    this.onPressed,
    this.size = 56,
    this.accentColor,
  });

  @override
  State<DesktopPlayButton> createState() => _DesktopPlayButtonState();
}

class _DesktopPlayButtonState extends State<DesktopPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? DesktopTheme.playButtonGreen;
    final isEnabled = widget.onPressed != null && !widget.isBuffering;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_controller.value * 0.05) + (_isHovered ? 0.05 : 0),
              child: AnimatedContainer(
                duration: DesktopTheme.durationFast,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled ? accent : accent.withOpacity(0.5),
                  boxShadow: _isHovered && isEnabled
                      ? DesktopTheme.shadowGlow(accent)
                      : DesktopTheme.shadowMd,
                ),
                child: widget.isBuffering
                    ? Padding(
                        padding: EdgeInsets.all(widget.size * 0.25),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: widget.size * 0.55,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Gradient text for headings
class DesktopGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color>? colors;

  const DesktopGradientText({
    super.key,
    required this.text,
    this.style,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors ?? DesktopTheme.accentGradientPurple;

    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(colors: gradientColors).createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Animated gradient background
class DesktopAnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animate;

  const DesktopAnimatedBackground({
    super.key,
    required this.child,
    this.colors,
    this.animate = true,
  });

  @override
  State<DesktopAnimatedBackground> createState() =>
      _DesktopAnimatedBackgroundState();
}

class _DesktopAnimatedBackgroundState extends State<DesktopAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColors =
        widget.colors ??
        [
          DesktopTheme.backgroundDeep,
          const Color(0xFF1A0A2E),
          const Color(0xFF0A1A2E),
          DesktopTheme.backgroundDeep,
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: baseColors,
              stops: [
                0.0,
                0.3 + (_controller.value * 0.1),
                0.7 - (_controller.value * 0.1),
                1.0,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Navigation item with hover animation
class DesktopNavItem extends StatefulWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  const DesktopNavItem({
    super.key,
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<DesktopNavItem> createState() => _DesktopNavItemState();
}

class _DesktopNavItemState extends State<DesktopNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          curve: DesktopTheme.curveSpring,
          margin: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingSm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            color: widget.isSelected
                ? accent.withOpacity(0.15)
                : _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
            border: widget.isSelected
                ? Border.all(color: accent.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: DesktopTheme.durationFast,
                child: Icon(
                  widget.isSelected
                      ? (widget.selectedIcon ?? widget.icon)
                      : widget.icon,
                  key: ValueKey(widget.isSelected),
                  color: widget.isSelected
                      ? accent
                      : _isHovered
                      ? DesktopTheme.textPrimary
                      : DesktopTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DesktopTheme.spacingMd),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? accent
                        : _isHovered
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hover-reactive icon button
class DesktopIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? activeColor;
  final bool isActive;
  final double size;

  const DesktopIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.activeColor,
    this.isActive = false,
    this.size = 20,
  });

  @override
  State<DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<DesktopIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final activeColor =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final iconColor = widget.isActive
        ? activeColor
        : widget.color ??
              (isEnabled
                  ? (_isHovered
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textSecondary)
                  : DesktopTheme.textMuted);

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.all(DesktopTheme.spacingSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            color: _isHovered && isEnabled
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
          ),
          child: Icon(widget.icon, color: iconColor, size: widget.size),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Progress slider with modern styling
class DesktopProgressSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final Color? activeColor;
  final double height;

  const DesktopProgressSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.height = 4,
  });

  @override
  State<DesktopProgressSlider> createState() => _DesktopProgressSliderState();
}

class _DesktopProgressSliderState extends State<DesktopProgressSlider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.activeColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _isHovered ? widget.height + 2 : widget.height,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _isHovered ? 6 : 0,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: accent,
          inactiveTrackColor: DesktopTheme.backgroundElevated,
          thumbColor: accent,
          overlayColor: accent.withOpacity(0.2),
        ),
        child: Slider(
          value: widget.value.clamp(0.0, 1.0),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
