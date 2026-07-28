import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicDemoRequest(options.path)) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }

    var token = _tokenStorage.cachedActiveAccessToken;
    if (token == null && !_tokenStorage.isCacheHydrated) {
      await _tokenStorage.hydrateCache();
      token = _tokenStorage.cachedActiveAccessToken;
    }

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  bool _isPublicDemoRequest(String value) {
    final path = Uri.tryParse(value)?.path ?? value.split('?').first;
    return path == '/demo' || path.startsWith('/demo/');
  }
}
