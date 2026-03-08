import 'package:dio/dio.dart';
import '../storage/storage_service.dart';
import 'api_endpoints.dart';

class ApiClient {
  static Dio? _instance;

  static Dio get dio {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expired — clear and let router redirect to login
            await StorageService.clearAll();
          }
          handler.next(error);
        },
      ),
    );

    return d;
  }

  /// Extracts the `data` field from a successful API response.
  static dynamic parseData(Response response) {
    return (response.data as Map<String, dynamic>)['data'];
  }

  /// Returns a friendly error message from a DioException.
  static String errorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Is the backend running?';
    }
    final data = e.response?.data;
    if (data is Map) return data['message'] ?? 'Something went wrong';
    return 'Something went wrong';
  }
}
