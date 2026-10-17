import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_exception.dart';
import 'package:open_vts/core/errors/app_error.dart';
import 'package:open_vts/core/errors/error_mapper.dart';

DioException _httpError(int status, {Object? data}) {
  final request = RequestOptions(path: '/dashboard');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status, data: data),
  );
}

void main() {
  for (final status in [500, 502, 503]) {
    for (final body in [
      null,
      '<html>nginx unavailable; private upstream address</html>',
      {'message': 'SQL error: private database credentials', 'error': 'stack'},
    ]) {
      test('$status response stays concise and hides backend details ($body)',
          () {
        final error = _httpError(status, data: body);
        final failure = ErrorMapper.from(error);
        expect(failure.message,
            'This information is temporarily unavailable. Please try again later.');
        expect(failure.canRetry, isTrue);
        expect(failure.code, '$status');
        expect(failure.originalError, same(error));
      });
    }
  }

  for (final status in [408, 504]) {
    test('HTTP $status explains a timeout', () {
      expect(ErrorMapper.from(_httpError(status)).message,
          'The request timed out. Please try again.');
    });
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  ]) {
    test('$type explains a timeout', () {
      final error = DioException(requestOptions: RequestOptions(), type: type);
      expect(ErrorMapper.from(error).message,
          'The request timed out. Please try again.');
    });
  }

  test('connection failures explain how to recover', () {
    final error = DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'SocketException with private host details',
    );
    expect(ErrorMapper.from(error).message,
        'Unable to connect. Check your internet connection and try again.');
  });

  test('rate limits ask the user to wait', () {
    final failure = ErrorMapper.from(_httpError(429));
    expect(failure.message,
        'Too many requests. Please wait a moment and try again.');
    expect(failure.canRetry, isTrue);
  });

  for (final (status, message) in [
    (401, 'Your session has expired. Please sign in again.'),
    (403, 'You do not have access to this information.'),
    (404, 'This information is no longer available.'),
    (410, 'This information is no longer available.'),
  ]) {
    test('$status does not offer a futile inline retry', () {
      final failure = ErrorMapper.from(_httpError(status));
      expect(failure.message, message);
      expect(failure.canRetry, isFalse);
    });
  }

  test('ApiException is classified by status without exposing its message', () {
    final failure = ErrorMapper.from(const ApiException(
      statusCode: 503,
      message: 'SQL error',
      details: '<html>private infrastructure</html>',
    ));
    expect(failure.message,
        'This information is temporarily unavailable. Please try again later.');
  });

  for (final error in [
    const ApiException(statusCode: 200, message: 'Invalid API response format'),
    const FormatException('Unexpected HTML'),
    StateError('internal state'),
    Exception('private error detail'),
    'DioException: raw error accidentally converted to text',
  ]) {
    test('unexpected failure is safe: ${error.runtimeType}', () {
      expect(ErrorMapper.from(error).message,
          'Unable to complete the request. Please try again.');
    });
  }

  test('explicit app validation messages remain usable', () {
    const error = AppError(message: 'Command text is required.');
    expect(ErrorMapper.from(error), same(error));
  });
}
