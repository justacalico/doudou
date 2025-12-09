import 'package:flutter/material.dart';
import '../services/responsive_service.dart';

/// A widget that provides different builders for mobile and desktop layouts.
/// 
/// Use this when you need custom widgets for each layout type within a screen.
/// The layout is determined by screen width, not device platform.
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for mobile layout (screen width < 768px)
  final WidgetBuilder mobileBuilder;
  
  /// Builder for desktop layout (screen width >= 768px)
  final WidgetBuilder desktopBuilder;

  const ResponsiveBuilder({
    super.key,
    required this.mobileBuilder,
    required this.desktopBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveService.desktopBreakpoint) {
          return desktopBuilder(context);
        } else {
          return mobileBuilder(context);
        }
      },
    );
  }
}

/// A widget that shows/hides based on screen size.
/// 
/// Use this to conditionally show elements only on certain screen sizes.
class ResponsiveVisibility extends StatelessWidget {
  /// The child widget to conditionally show
  final Widget child;
  
  /// Show on mobile layouts (screen width < 768px)
  final bool visibleOnMobile;
  
  /// Show on desktop layouts (screen width >= 768px)
  final bool visibleOnDesktop;
  
  /// Replacement widget when not visible (defaults to SizedBox.shrink())
  final Widget? replacement;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnDesktop = true,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= ResponsiveService.desktopBreakpoint;
        final shouldShow = isDesktop ? visibleOnDesktop : visibleOnMobile;
        
        if (shouldShow) {
          return child;
        } else {
          return replacement ?? const SizedBox.shrink();
        }
      },
    );
  }
}

/// A widget that shows different content based on screen size with a smooth transition.
class ResponsiveSwitch extends StatelessWidget {
  /// Widget to show on mobile screens
  final Widget mobile;
  
  /// Widget to show on desktop screens  
  final Widget desktop;

  const ResponsiveSwitch({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveService.desktopBreakpoint) {
          return desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Extension to easily check layout type from BuildContext
extension ResponsiveContext on BuildContext {
  /// Returns true if current screen should show desktop layout
  bool get isDesktopLayout => ResponsiveService.isDesktopLayout(this);
  
  /// Returns true if current screen should show mobile layout
  bool get isMobileLayout => ResponsiveService.isMobileLayout(this);
  
  /// Gets the current layout type
  LayoutType get layoutType => ResponsiveService.getLayoutType(this);
  
  /// Gets the current screen width
  double get screenWidth => ResponsiveService.getScreenWidth(this);
  
  /// Gets the current screen height
  double get screenHeight => ResponsiveService.getScreenHeight(this);
  
  /// Returns the number of grid columns based on screen size
  int gridColumns({double minItemWidth = 180}) => 
      ResponsiveService.getGridColumnCount(this, minItemWidth: minItemWidth);
}
