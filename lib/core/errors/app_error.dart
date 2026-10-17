class AppError {
  const AppError({
    required this.message,
    this.code,
    this.originalError,
    this.canRetry = true,
  });

  final String message;
  final String? code;
  final Object? originalError;
  final bool canRetry;
}
