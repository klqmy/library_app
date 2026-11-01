import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_exceptions.dart';
import 'config.dart';

class RequestToken {
  final CancelToken _token = CancelToken();
  bool get isCancelled => _token.isCancelled;
  void cancel() => _token.cancel('Запрошены новые данные');
}

class ApiClient {
  final Dio _dio;
  final bool useDemoLogin;
  final Duration retryPause;
  String? _accessToken;
  DateTime? _expiresAt;
  Future<void>? _loginFuture;

  ApiClient({
    Dio? dio,
    this.useDemoLogin = true,
    this.retryPause = const Duration(milliseconds: 350),
  }) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: apiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          if (kDebugMode) debugPrint('HTTP ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              'HTTP ${response.requestOptions.method} ${response.realUri} → ${response.statusCode}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              'HTTP ${error.requestOptions.method} ${error.requestOptions.uri} → ${error.response?.statusCode ?? error.type.name}',
            );
          }
          handler.next(error.copyWith(error: mapDioError(error)));
        },
      ),
    );
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    bool read = false,
    RequestToken? cancel,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (cancel?.isCancelled ?? false) throw const RequestCancelledException();
      try {
        return await action();
      } on DioException catch (error) {
        if (!read || !isNetworkError(error) || attempt >= 2) {
          throw mapDioError(error);
        }
        final delay = Future<void>.delayed(retryPause * (1 << attempt));
        if (cancel == null) {
          await delay;
        } else {
          await Future.any([delay, cancel._token.whenCancel.then((_) {})]);
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (!useDemoLogin) return;
    if (_accessToken != null && DateTime.now().isBefore(_expiresAt!)) return;
    if (_loginFuture != null) return _loginFuture;
    _loginFuture = () async {
      final response = await _guard(
        () => _dio.post(
          '/auth/login',
          data: {'username': apiUsername, 'password': apiPassword},
        ),
      );
      _accessToken = response.data['accessToken'] as String;
      _expiresAt = DateTime.now().add(
        Duration(seconds: (response.data['expiresIn'] as num).toInt() - 30),
      );
    }();
    try {
      await _loginFuture;
    } finally {
      _loginFuture = null;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    RequestToken? cancel,
  }) async {
    await _authenticate();
    return (await _guard(
      () => _dio.get(path, queryParameters: query, cancelToken: cancel?._token),
      read: true,
      cancel: cancel,
    )).data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    await _authenticate();
    return (await _guard(() => _dio.post(path, data: data))).data;
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    await _authenticate();
    return (await _guard(() => _dio.put(path, data: data))).data;
  }

  Future<void> delete(String path, {Map<String, dynamic>? query}) async {
    await _authenticate();
    await _guard(() => _dio.delete(path, queryParameters: query));
  }

  void close() => _dio.close(force: true);
}
