import 'package:flutter/material.dart';

/// Configuration options for the terminate and restart functionality.
class TerminateRestartOptions {
  /// Creates a new instance of [TerminateRestartOptions].
  const TerminateRestartOptions({
    this.showConfirmation = true,
    this.confirmationTitle,
    this.confirmationMessage,
    this.restartTimeout = const Duration(seconds: 3),
    this.customConfirmationDialog,
    this.onBeforeRestart,
    this.onAfterRestart,
    this.clearAppData = false,
    this.preserveKeychain = true,
    this.androidFlags = const AndroidRestartFlags(),
    this.iosOptions = const IOSRestartOptions(),
  });

  /// Whether to show a confirmation dialog before restarting.
  final bool showConfirmation;

  /// The title for the confirmation dialog.
  /// If null, a default title will be used.
  final String? confirmationTitle;

  /// The message for the confirmation dialog.
  /// If null, a default message will be used.
  final String? confirmationMessage;

  /// Timeout duration for the restart operation.
  /// After this duration, if the app hasn't restarted,
  /// a fallback message will be shown.
  final Duration restartTimeout;

  /// Custom confirmation dialog builder.
  /// If provided, this will be used instead of the default dialog.
  final Widget Function(BuildContext context)? customConfirmationDialog;

  /// Callback that will be called before the restart operation begins.
  /// Can be used to save state or perform cleanup.
  final Future<void> Function()? onBeforeRestart;

  /// Callback that will be called after the app has restarted.
  /// Note: This will be called in the new instance of the app.
  final Future<void> Function()? onAfterRestart;

  /// Whether to clear all app data during restart.
  /// This includes preferences, databases, and cached files.
  /// Does not affect keychain items unless [preserveKeychain] is false.
  final bool clearAppData;

  /// Whether to preserve keychain items when [clearAppData] is true.
  /// Only applicable if [clearAppData] is true.
  final bool preserveKeychain;

  /// Android-specific restart flags.
  final AndroidRestartFlags androidFlags;

  /// iOS-specific restart options.
  final IOSRestartOptions iosOptions;

  /// Creates a copy of this configuration with the given fields replaced with new values.
  TerminateRestartOptions copyWith({
    bool? showConfirmation,
    String? confirmationTitle,
    String? confirmationMessage,
    Duration? restartTimeout,
    Widget Function(BuildContext)? customConfirmationDialog,
    Future<void> Function()? onBeforeRestart,
    Future<void> Function()? onAfterRestart,
    bool? clearAppData,
    bool? preserveKeychain,
    AndroidRestartFlags? androidFlags,
    IOSRestartOptions? iosOptions,
  }) {
    return TerminateRestartOptions(
      showConfirmation: showConfirmation ?? this.showConfirmation,
      confirmationTitle: confirmationTitle ?? this.confirmationTitle,
      confirmationMessage: confirmationMessage ?? this.confirmationMessage,
      restartTimeout: restartTimeout ?? this.restartTimeout,
      customConfirmationDialog:
          customConfirmationDialog ?? this.customConfirmationDialog,
      onBeforeRestart: onBeforeRestart ?? this.onBeforeRestart,
      onAfterRestart: onAfterRestart ?? this.onAfterRestart,
      clearAppData: clearAppData ?? this.clearAppData,
      preserveKeychain: preserveKeychain ?? this.preserveKeychain,
      androidFlags: androidFlags ?? this.androidFlags,
      iosOptions: iosOptions ?? this.iosOptions,
    );
  }
}

/// Android-specific flags for app restart.
class AndroidRestartFlags {
  /// Creates a new instance of [AndroidRestartFlags].
  const AndroidRestartFlags({
    this.clearTop = true,
    this.newTask = true,
    this.clearTask = true,
    this.noAnimation = true,
    this.multipleTask = false,
    this.excludeFromRecents = false,
    this.noHistory = false,
  });

  /// Equivalent to [Intent.FLAG_ACTIVITY_CLEAR_TOP].
  final bool clearTop;

  /// Equivalent to [Intent.FLAG_ACTIVITY_NEW_TASK].
  final bool newTask;

  /// Equivalent to [Intent.FLAG_ACTIVITY_CLEAR_TASK].
  final bool clearTask;

  /// Equivalent to [Intent.FLAG_ACTIVITY_NO_ANIMATION].
  final bool noAnimation;

  /// Equivalent to [Intent.FLAG_ACTIVITY_MULTIPLE_TASK].
  final bool multipleTask;

  /// Equivalent to [Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS].
  final bool excludeFromRecents;

  /// Equivalent to [Intent.FLAG_ACTIVITY_NO_HISTORY].
  final bool noHistory;

  /// Creates a copy of this configuration with the given fields replaced with new values.
  AndroidRestartFlags copyWith({
    bool? clearTop,
    bool? newTask,
    bool? clearTask,
    bool? noAnimation,
    bool? multipleTask,
    bool? excludeFromRecents,
    bool? noHistory,
  }) {
    return AndroidRestartFlags(
      clearTop: clearTop ?? this.clearTop,
      newTask: newTask ?? this.newTask,
      clearTask: clearTask ?? this.clearTask,
      noAnimation: noAnimation ?? this.noAnimation,
      multipleTask: multipleTask ?? this.multipleTask,
      excludeFromRecents: excludeFromRecents ?? this.excludeFromRecents,
      noHistory: noHistory ?? this.noHistory,
    );
  }
}

/// iOS-specific options for app restart.
class IOSRestartOptions {
  /// Creates a new instance of [IOSRestartOptions].
  const IOSRestartOptions({
    this.exitCode = 0,
    this.immediate = true,
    this.preserveUserDefaults = true,
  });

  /// The exit code to use when terminating the app.
  final int exitCode;

  /// Whether to exit immediately or allow the app to clean up.
  final bool immediate;

  /// Whether to preserve NSUserDefaults during restart.
  final bool preserveUserDefaults;

  /// Creates a copy of this configuration with the given fields replaced with new values.
  IOSRestartOptions copyWith({
    int? exitCode,
    bool? immediate,
    bool? preserveUserDefaults,
  }) {
    return IOSRestartOptions(
      exitCode: exitCode ?? this.exitCode,
      immediate: immediate ?? this.immediate,
      preserveUserDefaults: preserveUserDefaults ?? this.preserveUserDefaults,
    );
  }
}
