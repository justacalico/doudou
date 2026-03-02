import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../terminate_restart_platform_interface.dart';

/// Options for restarting the app
class TerminateRestartOptions {
  /// Whether to terminate the app or just restart the UI
  final bool terminate;

  /// Whether to clear app data
  final bool clearData;

  /// Whether to preserve keychain data
  final bool preserveKeychain;

  /// Whether to preserve user defaults
  final bool preserveUserDefaults;

  /// Constructor
  const TerminateRestartOptions({
    this.terminate = true,
    this.clearData = false,
    this.preserveKeychain = false,
    this.preserveUserDefaults = false,
  });
}

/// Enum to specify the restart mode
enum RestartMode {
  /// Restart immediately without showing a dialog
  immediate,

  /// Show a confirmation dialog before restarting
  withConfirmation,
}

/// The main plugin class for restarting Flutter apps
class TerminateRestart {
  static TerminateRestart? _instance;

  /// Get the singleton instance
  static TerminateRestart get instance {
    _instance ??= TerminateRestart._();
    return _instance!;
  }

  /// Private constructor
  TerminateRestart._();

  final MethodChannel _internalChannel =
      const MethodChannel('com.ahmedsleem.terminate_restart/internal');

  bool _initialized = false;
  VoidCallback? _onRootReset;

  /// Initialize the plugin and set up internal handlers
  void initialize({VoidCallback? onRootReset}) {
    if (!_initialized) {
      _onRootReset = onRootReset;
      _internalChannel.setMethodCallHandler(_handleInternalMessages);
      _initialized = true;
    }
  }

  Future<dynamic> _handleInternalMessages(MethodCall call) async {
    switch (call.method) {
      case 'resetToRoot':
        if (_onRootReset != null) {
          _onRootReset!();
        } else {
          // Default behavior if no onRootReset callback is provided
          final rootElement = WidgetsBinding.instance.rootElement;
          if (rootElement != null) {
            // Find the first valid BuildContext
            BuildContext? context;
            void visitor(Element element) {
              if (!element.debugIsActive) return;
              context ??= element;
            }

            rootElement.visitChildren(visitor);

            if (context != null && context!.mounted) {
              // Get the navigator before any async operations
              final navigator = Navigator.of(context!, rootNavigator: true);

              // Reset navigation
              while (navigator.canPop()) {
                navigator.pop();
              }

              // Push to splash screen
              navigator.pushNamedAndRemoveUntil('/splash', (_) => false);
            }
          }
        }
        break;
    }
  }

  /// Wait for plugins to be registered after UI restart
  Future<void> _waitForPluginRegistration() async {
    // Initial delay to allow basic Flutter initialization
    await Future.delayed(const Duration(milliseconds: 500));

    // Force a rebuild of the widget tree
    final binding = WidgetsFlutterBinding.ensureInitialized();
    binding.reassembleApplication();

    // Additional delay to ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Force garbage collection
    await _internalChannel.invokeMethod<void>('gc');

    // Wait for plugins to be ready
    await Future.wait([
      // Try to initialize path provider
      _initializePathProvider(),
      // Try to initialize shared preferences
      _initializeSharedPreferences(),
    ]);
  }

  Future<void> _initializePathProvider() async {
    try {
      final pathProvider = await const MethodChannel(
              'dev.flutter.pigeon.path_provider_foundation.PathProviderApi')
          .invokeMethod<String>(
              'getDirectoryPath', {'type': 'applicationSupport'});
      debugPrint('Path provider initialized: $pathProvider');
    } catch (e) {
      debugPrint('Error initializing path provider: $e');
      // Try again after a short delay
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final pathProvider = await const MethodChannel(
                'dev.flutter.pigeon.path_provider_foundation.PathProviderApi')
            .invokeMethod<String>(
                'getDirectoryPath', {'type': 'applicationSupport'});
        debugPrint('Path provider initialized (retry): $pathProvider');
      } catch (e) {
        debugPrint('Error initializing path provider (retry): $e');
      }
    }
  }

  Future<void> _initializeSharedPreferences() async {
    try {
      final prefs = await const MethodChannel(
              'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi')
          .invokeMethod<Map<String, Object?>>('getAll');
      debugPrint('Shared preferences initialized: ${prefs?.length} items');
    } catch (e) {
      debugPrint('Error initializing shared preferences: $e');
      // Try again after a short delay
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final prefs = await const MethodChannel(
                'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi')
            .invokeMethod<Map<String, Object?>>('getAll');
        debugPrint(
            'Shared preferences initialized (retry): ${prefs?.length} items');
      } catch (e) {
        debugPrint('Error initializing shared preferences (retry): $e');
      }
    }
  }

  /// Restart the app with the given options
  Future<bool> restartApp({
    TerminateRestartOptions options = const TerminateRestartOptions(),
    RestartMode mode = RestartMode.immediate,
    String? dialogTitle,
    String? dialogMessage,
    String? confirmButtonText,
    String? cancelButtonText,
  }) async {
    if (!options.terminate) {
      try {
        // For UI-only restart, we need special handling
        final result = await TerminateRestartPlatform.instance.restartApp(
          clearData: options.clearData,
          preserveKeychain: options.preserveKeychain,
          preserveUserDefaults: options.preserveUserDefaults,
          terminate: false,
        );

        if (result) {
          // Wait for plugins to register after UI restart
          await _waitForPluginRegistration();

          // Additional platform channel setup
          ServicesBinding.instance.channelBuffers.push(
            'flutter/platform',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('SystemNavigator.pop'),
            ),
            (_) {}, // Adding the callback parameter
          );

          // Force reload plugins
          for (final plugin in [
            'PathProviderPlugin',
            'SharedPreferencesPlugin'
          ]) {
            try {
              await const MethodChannel('flutter/plugin_registry')
                  .invokeMethod<void>('reload', {'pluginKey': plugin});
            } catch (e) {
              debugPrint('Error reloading plugin $plugin: $e');
            }
          }
        }

        return result;
      } catch (e) {
        debugPrint('Error during UI restart: $e');
        return false;
      }
    }

    return TerminateRestartPlatform.instance.restartApp(
      clearData: options.clearData,
      preserveKeychain: options.preserveKeychain,
      preserveUserDefaults: options.preserveUserDefaults,
      terminate: true,
    );
  }
}
