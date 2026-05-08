class TerminateRestartResult {
  const TerminateRestartResult({
    required this.success,
    this.error,
    this.errorDetails,
    this.errorCode,
  });

  final bool success;

  final String? error;

  final String? errorDetails;

  final String? errorCode;

  factory TerminateRestartResult.success() {
    return const TerminateRestartResult(success: true);
  }

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
