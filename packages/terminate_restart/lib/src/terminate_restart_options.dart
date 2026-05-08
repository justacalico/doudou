import 'package:flutter/material.dart';

class TerminateRestartOptions {
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

  final bool showConfirmation;

  final String? confirmationTitle;

  final String? confirmationMessage;

  final Duration restartTimeout;

  final Widget Function(BuildContext context)? customConfirmationDialog;

  final Future<void> Function()? onBeforeRestart;

  final Future<void> Function()? onAfterRestart;

  final bool clearAppData;

  final bool preserveKeychain;

  final AndroidRestartFlags androidFlags;

  final IOSRestartOptions iosOptions;

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

class AndroidRestartFlags {
  const AndroidRestartFlags({
    this.clearTop = true,
    this.newTask = true,
    this.clearTask = true,
    this.noAnimation = true,
    this.multipleTask = false,
    this.excludeFromRecents = false,
    this.noHistory = false,
  });

  final bool clearTop;

  final bool newTask;

  final bool clearTask;

  final bool noAnimation;

  final bool multipleTask;

  final bool excludeFromRecents;

  final bool noHistory;

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

class IOSRestartOptions {
  const IOSRestartOptions({
    this.exitCode = 0,
    this.immediate = true,
    this.preserveUserDefaults = true,
  });

  final int exitCode;

  final bool immediate;

  final bool preserveUserDefaults;

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
