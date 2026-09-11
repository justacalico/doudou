import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/helper.dart';

const _channel = MethodChannel('gitlab.openlyst.doudou/background_task');

typedef BeginBackgroundTask = Future<int?> Function(String name);
typedef EndBackgroundTask = Future<void> Function(int id);

Future<int?> _platformBegin(String name) async {
  try {
    return await _channel.invokeMethod<int>('begin', {'name': name});
  } on MissingPluginException {
    return null;
  } catch (e, st) {
    printWarning(
        '[RECOVERABLE][opId=backgroundTask.begin] Failed to begin background task: $e\n$st');
    return null;
  }
}

Future<void> _platformEnd(int id) async {
  try {
    await _channel.invokeMethod<void>('end', {'id': id});
  } on MissingPluginException {
    // Plugin only exists on iOS; other platforms have nothing to end.
  } catch (e, st) {
    printWarning(
        '[RECOVERABLE][opId=backgroundTask.end] Failed to end background task: $e\n$st');
  }
}

class _BackgroundHold {
  int? nativeId;
  Timer? timer;
}

/// Holds iOS background-task assertions for spans of work that must keep
/// running while no audio is playing. A locked app lives on its audio
/// entitlement: the moment playback stops for a track change or an error
/// retry, iOS can suspend the process mid-transition and the pending platform
/// calls never land. Each acquire() maps to one
/// UIApplication.beginBackgroundTask, so overlapping sections stay covered
/// and every hold self-releases after [holdLimit], safely under the ~30s
/// grant iOS gives before it suspends (or kills, if a task is left open) the
/// app.
class BackgroundTaskGuard {
  BackgroundTaskGuard({
    BeginBackgroundTask? begin,
    EndBackgroundTask? end,
    bool Function()? enabled,
    Duration holdLimit = const Duration(seconds: 28),
  })  : _begin = begin ?? _platformBegin,
        _end = end ?? _platformEnd,
        _enabled = enabled ?? (() => GetPlatform.isIOS),
        _holdLimit = holdLimit;

  final BeginBackgroundTask _begin;
  final EndBackgroundTask _end;
  final bool Function() _enabled;
  final Duration _holdLimit;
  final Map<int, _BackgroundHold> _holds = {};
  int _nextToken = 0;

  /// Fired when a hold hits [holdLimit] and is force-released, which means
  /// whatever it was protecting never reached a playing state.
  void Function()? onExpired;

  bool get isHeld => _holds.isNotEmpty;

  int get activeHoldCount => _holds.length;

  /// Starts a protected section and returns its token. The hold is
  /// registered before any async work so [release] stays safe even while the
  /// platform begin call is still in flight.
  Future<int> acquire({String name = 'playback-transition'}) async {
    final token = ++_nextToken;
    final hold = _BackgroundHold();
    _holds[token] = hold;
    hold.timer = Timer(_holdLimit, () {
      onExpired?.call();
      unawaited(release(token));
    });
    if (_enabled()) {
      final id = await _begin(name);
      if (_holds.containsKey(token)) {
        hold.nativeId = id;
      } else if (id != null) {
        unawaited(_end(id));
      }
    }
    return token;
  }

  Future<void> release(int token) async {
    final hold = _holds.remove(token);
    if (hold == null) return;
    hold.timer?.cancel();
    final id = hold.nativeId;
    if (id != null) await _end(id);
  }

  Future<void> releaseAll() async {
    for (final token in _holds.keys.toList()) {
      await release(token);
    }
  }
}
