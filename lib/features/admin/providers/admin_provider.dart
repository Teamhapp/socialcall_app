import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';

class AdminState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? error,
  }) =>
      AdminState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState());

  Future<void> checkToken() async {
    final loggedIn = await AdminApi.isLoggedIn();
    state = state.copyWith(isLoggedIn: loggedIn);
  }

  Future<bool> login(String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await AdminApi.post(
        ApiEndpoints.adminLogin,
        data: {'password': password},
      );
      final token = (resp as Map<String, dynamic>)['token'] as String?;
      if (token == null || token.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Invalid response from server.');
        return false;
      }
      await AdminApi.saveToken(token);
      state = state.copyWith(isLoading: false, isLoggedIn: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AdminApi.errorMessage(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await AdminApi.clearToken();
    state = const AdminState();
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) => AdminNotifier());
