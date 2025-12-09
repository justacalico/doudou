import 'package:flutter/widgets.dart';

/// Service to handle responsive layout decisions based on screen size.
/// 
/// This service determines which UI layout to show (mobile or desktop)
/// based on the actual screen width rather than the device platform.
/// This ensures users always get the best experience for their current
/// screen size, whether they're on a large tablet, small laptop, or
/// resized browser window.
class ResponsiveService {
  /// Breakpoint for switching between mobile and desktop layouts.
  /// Screens wider than this will show the desktop layout.
  /// 
  /// 768px is chosen because:
  /// - It's the typical tablet portrait width boundary
  /// - Desktop features need at least this width to be usable
  /// - Most mobile phones max out around 500px wide
  static const double desktopBreakpoint = 768.0;
  
  /// Minimum width for showing the full desktop sidebar
  static const double fullSidebarBreakpoint = 1024.0;
  
  /// Width at which we consider the screen "large" (full desktop experience)
  static const double largeDesktopBreakpoint = 1440.0;
  
  /// Determines if the current screen should show the desktop layout.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns true if screen width >= desktopBreakpoint
  static bool isDesktopLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= desktopBreakpoint;
  }
  
  /// Determines if the current screen should show the mobile layout.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns true if screen width < desktopBreakpoint
  static bool isMobileLayout(BuildContext context) {
    return !isDesktopLayout(context);
  }
  
  /// Determines if we should show a compact sidebar (icons only).
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns true if screen is between desktop and full sidebar breakpoints
  static bool shouldShowCompactSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= desktopBreakpoint && screenWidth < fullSidebarBreakpoint;
  }
  
  /// Determines if we should show the full expanded sidebar.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns true if screen width >= fullSidebarBreakpoint
  static bool shouldShowFullSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= fullSidebarBreakpoint;
  }
  
  /// Determines if this is a large desktop screen.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns true if screen width >= largeDesktopBreakpoint
  static bool isLargeDesktop(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= largeDesktopBreakpoint;
  }
  
  /// Gets the current layout type as an enum.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns the appropriate LayoutType for the current screen size
  static LayoutType getLayoutType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < desktopBreakpoint) {
      return LayoutType.mobile;
    } else if (screenWidth < fullSidebarBreakpoint) {
      return LayoutType.tabletDesktop;
    } else if (screenWidth < largeDesktopBreakpoint) {
      return LayoutType.desktop;
    } else {
      return LayoutType.largeDesktop;
    }
  }
  
  /// Gets the screen width from context.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns the current screen width in logical pixels
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  /// Gets the screen height from context.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// Returns the current screen height in logical pixels
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  /// Calculates the number of grid columns for album/playlist grids.
  /// 
  /// [context] - BuildContext to get MediaQuery data
  /// [minItemWidth] - Minimum width for each grid item (default 180)
  /// Returns the number of columns that fit on screen
  static int getGridColumnCount(BuildContext context, {double minItemWidth = 180}) {
    final screenWidth = getScreenWidth(context);
    // Account for padding/margins (approximately 32px on each side)
    final availableWidth = screenWidth - 64;
    // For desktop, also account for sidebar width
    final sidebarWidth = isDesktopLayout(context) ? 250.0 : 0.0;
    final contentWidth = availableWidth - sidebarWidth;
    
    return (contentWidth / minItemWidth).floor().clamp(2, 8);
  }
}

/// Enum representing the different layout types based on screen size.
enum LayoutType {
  /// Mobile layout - optimized for phones and small screens
  /// Screen width < 768px
  mobile,
  
  /// Tablet/compact desktop layout - shows compact sidebar
  /// Screen width >= 768px and < 1024px
  tabletDesktop,
  
  /// Standard desktop layout - shows full sidebar
  /// Screen width >= 1024px and < 1440px
  desktop,
  
  /// Large desktop layout - full experience with extra space
  /// Screen width >= 1440px
  largeDesktop,
}

/// Extension on LayoutType for convenience methods
extension LayoutTypeExtension on LayoutType {
  /// Returns true if this layout type should show mobile UI
  bool get isMobile => this == LayoutType.mobile;
  
  /// Returns true if this layout type should show desktop UI
  bool get isDesktop => this != LayoutType.mobile;
  
  /// Returns true if this layout type should show a sidebar
  bool get hasSidebar => this != LayoutType.mobile;
  
  /// Returns true if the sidebar should be compact (icons only)
  bool get hasCompactSidebar => this == LayoutType.tabletDesktop;
  
  /// Returns true if the sidebar should be fully expanded
  bool get hasFullSidebar => this == LayoutType.desktop || this == LayoutType.largeDesktop;
}
