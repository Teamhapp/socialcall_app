import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_endpoints.dart';

/// Dedicated Dio instance for admin API calls.
/// Uses a separate 'admin_token' key in SharedPreferences, distinct from the
/// regular user JWT so admin sessions don't interfere with normal auth.
class AdminApi {
  static const _tokenKey = 'admin_token';
  static Dio? _instance;

  static Dio get _dio {
    _instance ??= _create();
    return _instance!;
  }

  static Dio _create() {
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
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            await clearToken();
          }
          handler.next(error);
        },
      ),
    );

    return d;
  }

  // ── Token helpers ───────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────────

  static Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final resp = await _dio.get(path, queryParameters: queryParameters);
    return resp.data;
  }

  static Future<dynamic> post(String path, {dynamic data}) async {
    final resp = await _dio.post(path, data: data);
    return resp.data;
  }

  static Future<dynamic> patch(String path, {dynamic data}) async {
    final resp = await _dio.patch(path, data: data);
    return resp.data;
  }

  static Future<dynamic> delete(String path) async {
    final resp = await _dio.delete(path);
    return resp.data;
  }

  /// Extracts the `data` field from a response map, falling back to the
  /// full map if the key doesn't exist (some admin endpoints return flat).
  static dynamic parseData(dynamic raw) {
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }

  /// Returns a user-friendly message from an exception.
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out. Check your network.';
        case DioExceptionType.connectionError:
          return 'Cannot reach server. Check your network.';
        default:
          return e.message ?? 'Something went wrong.';
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }
}
