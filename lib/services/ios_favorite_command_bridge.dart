import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/helper.dart';

/// Bridges the iOS lock screen heart button (MPRemoteCommandCenter's
/// likeCommand) to the player's favourite state.
///
/// Tapping the heart on the lock screen sends `onFavoritePressed` over the
/// channel and the current favourite state is pushed back through
/// `setFavoriteState` so the indicator stays in sync. audio_service disables
/// the feedback commands when it activates the command center, so the state
/// is re-applied on song, favourite and playback-state changes.
class IosFavoriteCommandBridge {
  IosFavoriteCommandBridge({
    required Rx<bool> isFavorite,
    required Rx<MediaItem?> currentSong,
    required Stream<PlaybackState> playbackState,
    required Future<void> Function() onToggleFavorite,
    MethodChannel? channel,
  })  : _isFavorite = isFavorite,
        _currentSong = currentSong,
        _playbackState = playbackState,
        _onToggleFavorite = onToggleFavorite,
        _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'gitlab.openlyst.doudou/lockscreen_favorite';

  final Rx<bool> _isFavorite;
  final Rx<MediaItem?> _currentSong;
  final Stream<PlaybackState> _playbackState;
  final Future<void> Function() _onToggleFavorite;
  final MethodChannel _channel;
  final _subs = <StreamSubscription<dynamic>>[];

  void start() {
    _channel.setMethodCallHandler(_handleCall);
    _subs.add(_isFavorite.listen((_) => _pushState()));
    _subs.add(_currentSong.listen((_) => _pushState()));
    // audio_service disables the feedback commands when it activates the
    // command center on the first playing state (and re-activates it after
    // stopService). Its setState platform call is enqueued before this
    // listener runs for the same emission, so re-pushing here lands after
    // the disable and re-enables the like command.
    _subs.add(_playbackState
        .map((s) => '${s.playing}:${s.processingState.name}')
        .distinct()
        .listen((_) => _pushState()));
    _pushState();
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method == 'onFavoritePressed' && _currentSong.value != null) {
      await _onToggleFavorite();
    }
    return null;
  }

  void _pushState() {
    final hasSong = _currentSong.value != null;
    unawaited(_channel.invokeMethod<void>('setFavoriteState', {
      'enabled': hasSong,
      'active': hasSong && _isFavorite.value,
    }).catchError((Object e) {
      printWarning('IosFavoriteCommandBridge: failed to push state: $e');
      return null;
    }));
  }
}
