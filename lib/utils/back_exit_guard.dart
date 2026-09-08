/// Tracks consecutive back presses so the app only quits when the user
/// presses back twice inside a short window.
class BackExitGuard {
  BackExitGuard({this.window = const Duration(seconds: 2)});

  final Duration window;
  DateTime? _armedUntil;

  /// Returns true when this press lands inside [window] of the previous one,
  /// meaning the exit should go ahead. Otherwise the guard stays armed for
  /// [window] from [now].
  bool confirmExit(DateTime now) {
    final armed = _armedUntil;
    if (armed != null && !now.isAfter(armed)) {
      _armedUntil = null;
      return true;
    }
    _armedUntil = now.add(window);
    return false;
  }
}
