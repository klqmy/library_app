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
  final Duration retryPause;
  String? Function()? tokenProvider;
  Future<void> Function(String? failedToken)? refreshSession;
  Future<void> Function()? expireSession;

  ApiClient({
    Dio? dio,
    String baseUrl = apiBaseUrl,
    this.retryPause = const Duration(milliseconds: 350),
  }) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.call();
          if (options.extra['public'] != true && token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (kDebugMode) {
            debugPrint(
              'HTTP ${request.method} ${request.uri} → ${error.response?.statusCode ?? error.type.name}',
            );
          }
          final authRequest = request.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 &&
              !authRequest &&
              request.extra['public'] != true &&
              refreshSession != null &&
              tokenProvider?.call() != null) {
            if (request.extra['authRetried'] == true) {
              await expireSession?.call();
            } else {
              final header = request.headers['Authorization']?.toString();
              try {
                await refreshSession!(header?.replaceFirst('Bearer ', ''));
              } catch (_) {
                await expireSession?.call();
                handler.reject(
                  error.copyWith(
                    error: const UnauthorizedException(
                      'Сессия завершена. Войдите снова.',
                    ),
                  ),
                );
                return;
              }
              final retry = request.copyWith(
                headers: {
                  ...request.headers,
                  'Authorization': 'Bearer ${tokenProvider?.call()}',
                },
                extra: {...request.extra, 'authRetried': true},
              );
              try {
                handler.resolve(await _dio.fetch<dynamic>(retry));
              } on DioException catch (next) {
                handler.reject(next.copyWith(error: mapDioError(next)));
              }
              return;
            }
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

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    RequestToken? cancel,
  }) async => (await _guard(
    () => _dio.get(path, queryParameters: query, cancelToken: cancel?._token),
    read: true,
    cancel: cancel,
  )).data;
  Future<dynamic> post(
    String path, {
    dynamic data,
    bool authenticated = true,
  }) async => (await _guard(
    () => _dio.post(
      path,
      data: data,
      options: Options(extra: {'public': !authenticated}),
    ),
  )).data;
  Future<dynamic> put(String path, {dynamic data}) async =>
      (await _guard(() => _dio.put(path, data: data))).data;
  Future<void> delete(String path, {Map<String, dynamic>? query}) async {
    await _guard(() => _dio.delete(path, queryParameters: query));
  }

  void close() => _dio.close(force: true);
}
