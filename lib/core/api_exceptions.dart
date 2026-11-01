import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Сервер недоступен. Проверьте подключение и повторите попытку.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Не удалось войти в учебный API. Проверьте учётную запись.',
  ]);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этой операции.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(
    this.errors, [
    super.message = 'Проверьте поля формы.',
  ]);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка сервера. Повторите попытку позже.',
  ]);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('Запрос отменён.');
}

ApiException mapHttpError(int? status, dynamic data) {
  final message = data is Map ? data['message']?.toString() : null;
  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется авторизация.'),
    403 => ForbiddenException(message ?? 'Недостаточно прав.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(
      message ?? 'Операция конфликтует с состоянием данных.',
    ),
    422 => ValidationException({
      if (data is Map && data['errors'] is Map)
        for (final entry in (data['errors'] as Map).entries)
          entry.key.toString(): entry.value.toString(),
    }, message ?? 'Проверьте поля формы.'),
    _ => ServerException(
      'Ошибка сервера (${status ?? 'нет ответа'}). Повторите попытку позже.',
    ),
  };
}

bool isNetworkError(DioException error) => const {
  DioExceptionType.connectionTimeout,
  DioExceptionType.sendTimeout,
  DioExceptionType.receiveTimeout,
  DioExceptionType.connectionError,
}.contains(error.type);

ApiException mapDioError(DioException error) {
  if (error.error is ApiException) return error.error as ApiException;
  if (error.type == DioExceptionType.cancel) {
    return const RequestCancelledException();
  }
  if (error.response != null) {
    return mapHttpError(error.response!.statusCode, error.response!.data);
  }
  if (isNetworkError(error)) {
    return const NetworkException(
      'Сервер недоступен. Проверьте подключение и повторите попытку. Если сервер работает, проверьте CORS в консоли браузера.',
    );
  }
  return const ServerException(
    'Не удалось обработать ответ сервера. Повторите попытку.',
  );
}
