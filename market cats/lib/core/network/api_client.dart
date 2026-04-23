import 'package:dio/dio.dart';

import '../auth/auth_controller.dart';
import '../config/app_settings.dart';

class ApiClient {
  static const Duration _kNetworkTimeout = Duration(seconds: 90);
  static const int _kMaxConnectRetries = 1;

  ApiClient({
    required this.settings,
    required this.authController,
  }) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: _kNetworkTimeout,
        receiveTimeout: _kNetworkTimeout,
        sendTimeout: _kNetworkTimeout,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = authController.jwt;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${Uri.encodeComponent(token)}';
          }
          options.baseUrl = settings.apiBaseUrl;
          handler.next(options);
        },
        onError: (err, handler) async {
          final retryCount = (err.requestOptions.extra['__retryCount'] as int?) ?? 0;
          final shouldRetry =
              (err.type == DioExceptionType.connectionTimeout ||
                  err.type == DioExceptionType.connectionError) &&
              retryCount < _kMaxConnectRetries;
          if (!shouldRetry) {
            handler.next(err);
            return;
          }

          try {
            final retryOptions = Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
              responseType: err.requestOptions.responseType,
              contentType: err.requestOptions.contentType,
              followRedirects: err.requestOptions.followRedirects,
              receiveDataWhenStatusError: err.requestOptions.receiveDataWhenStatusError,
              validateStatus: err.requestOptions.validateStatus,
              receiveTimeout: err.requestOptions.receiveTimeout,
              sendTimeout: err.requestOptions.sendTimeout,
              extra: <String, dynamic>{
                ...err.requestOptions.extra,
                '__retryCount': retryCount + 1,
              },
            );
            final response = await _dio.request<dynamic>(
              err.requestOptions.path,
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
              options: retryOptions,
              cancelToken: err.requestOptions.cancelToken,
              onReceiveProgress: err.requestOptions.onReceiveProgress,
              onSendProgress: err.requestOptions.onSendProgress,
            );
            handler.resolve(response);
            return;
          } catch (_) {
            handler.next(err);
            return;
          }
        },
      ),
    );
  }

  late final Dio _dio;
  final AppSettings settings;
  final AuthController authController;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return response.data ?? <String, dynamic>{};
  }
}
