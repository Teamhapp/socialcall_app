import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/storage_service.dart';
import '../../models/user_model.dart';

// ── State ──────────────────────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  // Check stored token on startup
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final loggedIn = await StorageService.isLoggedIn();
      if (loggedIn) {
        final userData = await StorageService.getUser();
        if (userData != null) {
          state = AuthState(
            user: UserModel.fromJson(userData),
            isAuthenticated: true,
          );
          _refreshProfile();
          return;
        }
      }
    } catch (_) {}
    state = const AuthState();
  }

  Future<void> _refreshProfile() async {
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.profile);
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final user = UserModel.fromJson(data);
      await StorageService.saveUser(data);
      state = state.copyWith(user: user, isAuthenticated: true);
    } catch (_) {}
  }

  // ── Shared: save tokens + user from any auth response ───────────────────────
  Future<UserModel> _handleAuthResponse(Map<String, dynamic> data) async {
    final accessToken  = data['accessToken']  as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson     = data['user']         as Map<String, dynamic>;
    await StorageService.saveTokens(accessToken, refreshToken);
    await StorageService.saveUser(userJson);
    final user = UserModel.fromJson(userJson);
    state = AuthState(user: user, isAuthenticated: true);
    return user;
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────────
  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.dio.post(ApiEndpoints.sendOtp, data: {'phone': phone});
      state = state.copyWith(isLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────────
  Future<UserModel> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.verifyOtp,
        data: {'phone': phone, 'otp': otp},
      );
      return await _handleAuthResponse(
          ApiClient.parseData(resp) as Map<String, dynamic>);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Register with phone + password ──────────────────────────────────────────
  Future<UserModel> register(String phone, String password,
      {String? name}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'phone': phone,
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      return await _handleAuthResponse(
          ApiClient.parseData(resp) as Map<String, dynamic>);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Login with phone + password ──────────────────────────────────────────────
  Future<UserModel> loginWithPassword(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.loginPassword,
        data: {'phone': phone, 'password': password},
      );
      return await _handleAuthResponse(
          ApiClient.parseData(resp) as Map<String, dynamic>);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Set / change password (authenticated user) ───────────────────────────────
  Future<void> setPassword(String newPassword, {String? currentPassword}) async {
    await ApiClient.dio.post(
      ApiEndpoints.setPassword,
      data: {
        'newPassword': newPassword,
        'currentPassword': ?currentPassword,
      },
    );
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(hasPassword: true));
    }
  }

  // ── Refresh wallet balance ────────────────────────────────────────────────────
  Future<void> refreshBalance() => _refreshProfile();

  // ── Logout ───────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await ApiClient.dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await StorageService.clearAll();
    state = const AuthState();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
