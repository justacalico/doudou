import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/responsive_service.dart';
import '../providers/app_state.dart';
import '../screens/login/login.dart';
import '../screens/partials/navbar/navbar.dart';
import '../desktop/templates/desktop_layout.dart';

/// A widget that automatically switches between mobile and desktop layouts
/// based on the current screen size.
/// 
/// This widget listens to screen size changes and rebuilds with the appropriate
/// layout when the screen crosses the breakpoint threshold. This enables:
/// - Large tablets to show desktop UI when in landscape
/// - Browser windows to adapt as they're resized
/// - A consistent experience based on available screen space
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the constraints to determine layout type
        // This will rebuild when the window/screen size changes
        final isDesktop = constraints.maxWidth >= ResponsiveService.desktopBreakpoint;
        
        return Consumer<AppState>(
          builder: (context, appState, child) {
            // Show loading screen while initializing
            if (!appState.isInitialized) {
              return _buildLoadingScreen(isDesktop);
            }

            // Show login screen if not logged in
            if (!appState.isLoggedIn) {
              return _buildLoginScreen(isDesktop);
            }

            // Show the appropriate main layout based on screen size
            if (isDesktop) {
              return const _DesktopHomeWrapper();
            } else {
              return const HomeScreen();
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen(bool isDesktop) {
    if (isDesktop) {
      // Material design loading for desktop
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Cupertino design loading for mobile
      return const CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 20),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildLoginScreen(bool isDesktop) {
    // LoginScreen adapts internally, but we wrap it appropriately
    return const LoginScreen();
  }
}

/// Wrapper for the desktop home that uses DesktopLayout
class _DesktopHomeWrapper extends StatelessWidget {
  const _DesktopHomeWrapper();

  @override
  Widget build(BuildContext context) {
    // DesktopLayout handles all desktop navigation and layout
    return const DesktopLayout();
  }
}

/// A widget that provides different builders for mobile and desktop layouts.
/// 
/// Use this when you need custom widgets for each layout type within a screen.
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
}
