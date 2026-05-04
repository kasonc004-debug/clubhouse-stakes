import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

class ApiClient {
  late final Dio _dio;
  final SecureStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) =>
      _dio.get(path, queryParameters: queryParams);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  // Multipart upload — returns the parsed response.
  Future<Response> upload(String path, FormData data) =>
      _dio.post(path, data: data);
}

// Typed API error
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;

  static ApiException fromDio(DioException e) {
    final data = e.response?.data;
    final msg  = (data is Map) ? (data['error'] ?? 'Unknown error') : e.message ?? 'Network error';
    return ApiException(msg.toString(), statusCode: e.response?.statusCode);
  }
}
