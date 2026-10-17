import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'app_error.dart';

class ErrorMapper {
  const ErrorMapper._();

  static AppError from(Object error) {
    // AppError messages are authored by the app. Raw API messages, HTML error
    // pages and exception descriptions must never become user-facing text.
    if (error is AppError) return error;
    final statusCode = switch (error) {
      DioException() => error.response?.statusCode,
      ApiException() => error.statusCode,
      _ => null,
    };
    final (message, canRetry) = switch (statusCode ?? 0) {
      401 => ('Your session has expired. Please sign in again.', false),
      403 => ('You do not have access to this information.', false),
      404 || 410 => ('This information is no longer available.', false),
      408 || 504 => ('The request timed out. Please try again.', true),
      429 => ('Too many requests. Please wait a moment and try again.', true),
      >= 500 => (
          'This information is temporarily unavailable. Please try again later.',
          true,
        ),
      _ => (_messageForException(error), true),
    };

    return AppError(
      message: message,
      code: statusCode?.toString(),
      originalError: error,
      canRetry: canRetry,
    );
  }

  static String _messageForException(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Please try again.',
        DioExceptionType.connectionError =>
          'Unable to connect. Check your internet connection and try again.',
        DioExceptionType.badCertificate =>
          'A secure connection could not be established. Please try again later.',
        DioExceptionType.cancel =>
          'The request was cancelled. Please try again.',
        _ => 'Unable to complete the request. Please try again.',
      };
    }
    return 'Unable to complete the request. Please try again.';
  }
}
