part of 'player_controller.dart';

mixin _PlayerMiscMixin on _PlayerControllerBase {
  Future<void> openEqualizer() async {
    await _audioHandler.customAction("openEqualizer");
  }

  void notifyPlayError(String message) {
    logPlaybackDebugError('notifyPlayError',
        'song=${currentSong.value?.id ?? 'unknown'}, message=$message');
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
    final l10n = l10nFromPrefs();
    if (raw.startsWith('networkError')) {
      return l10n.networkError;
    }

    var message = raw.trim();
    if (message.isEmpty) {
      return l10n.unableToStartPlayback;
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
      return l10n.trackNotAvailableOnServer;
    }

    if (message.startsWith('DioException')) {
      final m = RegExp(r'status code of (\d+)').firstMatch(message);
      final code = m?.group(1);
      return code != null
          ? l10n.serverErrorCode(code)
          : l10n.serverErrorPlayback;
    }

    // Clamp any remaining message to a sane length for the snackbar.
    const maxLen = 180;
    if (message.length > maxLen) {
      return '${message.substring(0, maxLen - 1)}…';
    }
    return message;
  }

}
