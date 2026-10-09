import 'package:dio/dio.dart';

import '../json/json_utils.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'api_signature.dart';

typedef UnauthorizedHandler = Future<void> Function();

/// Thin, typed wrapper over [Dio].
///
/// Responsibilities:
/// * attach the session id, common device parameters and a request signature;
/// * normalise transport/business errors into [ApiException];
/// * keep a single retry path for transient failures.
class ApiClient {
  ApiClient(this.config, {Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = Headers.jsonContentType
      ..validateStatus = (_) => true;
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final authorized = options.extra['authorized'] != false;
              options.headers['Accept'] = 'application/json';
              options.headers['X-Client-Platform'] = 'flutter';
              if (authorized) {
                final sessionId = await config.sessionStore.sessionId();
                if (sessionId.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $sessionId';
                }
                final secret = config.signatureSecret;
                if (secret != null && secret.isNotEmpty) {
                  final timestamp = config.timestamp();
                  final nonce = ApiSignature.nonce();
                  options.headers['X-Timestamp'] = '$timestamp';
                  options.headers['X-Nonce'] = nonce;
                  options.headers['X-Signature'] = ApiSignature.sign(
                    params: _flatten(options),
                    secret: secret,
                    nonce: nonce,
                    timestamp: timestamp,
                  );
                }
              }
              handler.next(options);
            },
          ),
        );
  }

  final ApiConfig config;
  final Dio dio;

  UnauthorizedHandler? onUnauthorized;
  bool _handlingUnauthorized = false;

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? params,
    bool authorized = true,
  }) {
    return _send(
      path,
      authorized: authorized,
      request: (options) => dio.get<dynamic>(path, queryParameters: params, options: options),
    );
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? data,
    bool authorized = true,
  }) {
    return _send(
      path,
      authorized: authorized,
      request: (options) => dio.post<dynamic>(path, data: data, options: options),
    );
  }

  Future<ApiResponse> _send(
    String path, {
    required bool authorized,
    required Future<Response<dynamic>> Function(Options options) request,
  }) async {
    final options = Options(extra: {'authorized': authorized});
    try {
      final response = await request(options);
      return _mapResponse(response);
    } on DioException catch (error, stackTrace) {
      throw _mapDioException(error, stackTrace);
    }
  }

  ApiResponse _mapResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      _notifyUnauthorized();
      throw ApiException.unauthorized();
    }
    final body = response.data;
    final map = body is Map<String, dynamic>
        ? body
        : body is Map
            ? Map<String, dynamic>.from(body)
            : <String, dynamic>{'code': status, 'message': '', 'data': body};
    final decoded = ApiResponse.fromJson(map);
    if (status >= 400) {
      throw ApiException(
        decoded.message.isEmpty ? 'Request failed ($status).' : decoded.message,
        code: 'http_$status',
        statusCode: status,
      );
    }
    return decoded;
  }

  ApiException _mapDioException(DioException error, StackTrace stackTrace) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout(error);
      case DioExceptionType.cancel:
        return ApiException.cancelled();
      case DioExceptionType.connectionError:
        return ApiException.network(error);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401) {
          _notifyUnauthorized();
          return ApiException.unauthorized();
        }
        final message = error.response?.data is Map
            ? Map<String, dynamic>.from(error.response!.data as Map)
                .stringValue('message', fallback: 'Request failed ($status).')
            : 'Request failed ($status).';
        return ApiException(message, code: 'http_$status', statusCode: status, cause: error);
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return ApiException.network(error);
    }
  }

  void _notifyUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    final handler = onUnauthorized;
    Future<void>.microtask(() async {
      try {
        await handler?.call();
      } finally {
        _handlingUnauthorized = false;
      }
    });
  }

  Map<String, String> _flatten(RequestOptions options) {
    final result = <String, String>{};
    void add(String key, Object? value) {
      if (value == null) return;
      result[key] = value.toString();
    }

    options.queryParameters.forEach((key, value) => add(key.toString(), value));
    final data = options.data;
    if (data is Map) {
      data.forEach((key, value) => add(key.toString(), value));
    }
    return result;
  }
}
