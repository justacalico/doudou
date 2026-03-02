/// Represents the result of a terminate and restart operation.
class TerminateRestartResult {
  /// Creates a new instance of [TerminateRestartResult].
  const TerminateRestartResult({
    required this.success,
    this.error,
    this.errorDetails,
    this.errorCode,
  });

  /// Whether the operation was successful.
  final bool success;

  /// Error message if the operation failed.
  final String? error;

  /// Additional error details if available.
  final String? errorDetails;

  /// Platform-specific error code if available.
  final String? errorCode;

  /// Creates a successful result.
  factory TerminateRestartResult.success() {
    return const TerminateRestartResult(success: true);
  }

  /// Creates a failed result with the given error information.
  factory TerminateRestartResult.failure({
    String? error,
    String? errorDetails,
    String? errorCode,
  }) {
    return TerminateRestartResult(
      success: false,
      error: error,
      errorDetails: errorDetails,
      errorCode: errorCode,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'TerminateRestartResult(success: true)';
    }
    return 'TerminateRestartResult(success: false, error: $error, details: $errorDetails, code: $errorCode)';
  }
}
