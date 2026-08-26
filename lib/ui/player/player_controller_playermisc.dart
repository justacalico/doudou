part of 'player_controller.dart';

mixin _PlayerMiscMixin on _PlayerControllerBase {
  Future<void> openEqualizer() async {
    await _audioHandler.customAction("openEqualizer");
  }

  void notifyPlayError(String message) {
    _diag.logEvent(
      category: 'ui_error',
      message: 'notify_play_error',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
      data: {'status': message},
    );
    final displayMessage = _formatPlayErrorMessage(message);
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(snackbar(ctx, displayMessage, size: SnackBarSize.MEDIUM));
  }

  String _formatPlayErrorMessage(String raw) {
    final ctx = Get.context;
    if (raw.startsWith('networkError')) {
      return ctx != null
          ? AppLocalizations.of(ctx)!.networkError
          : 'Network error while starting playback.';
    }

    var message = raw.trim();
    if (message.isEmpty) {
      return 'Unable to start playback.';
    }

    // Handle errors returned as a JSON object, e.g. from custom backends.
    if (message.startsWith('{') && message.endsWith('}')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      } catch (_) {
        // fall through to other handlers
      }
    }

    if (message.contains('TrackNotFound')) {
      return 'Track is no longer available on the server.';
    }

    if (message.startsWith('DioException')) {
      final m = RegExp(r'status code of (\d+)').firstMatch(message);
      final code = m?.group(1);
      return code != null
          ? 'Server error $code while starting playback.'
          : 'Server error while starting playback.';
    }

    // Clamp any remaining message to a sane length for the snackbar.
    const maxLen = 180;
    if (message.length > maxLen) {
      return '${message.substring(0, maxLen - 1)}…';
    }
    return message;
  }

}
