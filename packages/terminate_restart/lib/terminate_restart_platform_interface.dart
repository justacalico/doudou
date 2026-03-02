import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'src/method_channel.dart';

/// The interface that implementations of terminate_restart must implement.
///
/// Platform implementations should extend this class rather than implement it as `terminate_restart`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [TerminateRestartPlatform] methods.
abstract class TerminateRestartPlatform extends PlatformInterface {
  /// Constructs a TerminateRestartPlatform.
  TerminateRestartPlatform() : super(token: _token);

  static final Object _token = Object();

  static TerminateRestartPlatform _instance = MethodChannelTerminateRestart();

  /// The default instance of [TerminateRestartPlatform] to use.
  ///
  /// Defaults to [MethodChannelTerminateRestart].
  static TerminateRestartPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TerminateRestartPlatform] when
  /// they register themselves.
  static set instance(TerminateRestartPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Restarts the app with the given options.
  ///
  /// Returns true if the restart was successful, false otherwise.
  Future<bool> restartApp({
    bool clearData = false,
    bool preserveKeychain = false,
    bool preserveUserDefaults = false,
    bool terminate = true,
  }) {
    throw UnimplementedError('restartApp() has not been implemented.');
  }

  /// Forces garbage collection to clean up old platform channels
  Future<void> gc() {
    throw UnimplementedError('gc() has not been implemented.');
  }
}
