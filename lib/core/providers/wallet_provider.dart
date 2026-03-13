import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../../models/transaction_model.dart';

// ── State ──────────────────────────────────────────────────────────────────────
class WalletState {
  final double balance;
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.balance = 0.0,
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    double? balance,
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
  }) =>
      WalletState(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState()) {
    fetchWallet();
  }

  Future<void> fetchWallet() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.walletTransactions);
      final txnData = ApiClient.parseData(resp) as List;
      final transactions = txnData
          .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
          .toList();

      // Also get balance from profile
      final profileResp = await ApiClient.dio.get(ApiEndpoints.profile);
      final profileData =
          ApiClient.parseData(profileResp) as Map<String, dynamic>;
      // wallet_balance is a PostgreSQL DECIMAL — arrives as String from node-postgres
      final rawBal = profileData['wallet_balance'];
      final balance = rawBal == null
          ? 0.0
          : (rawBal is num ? rawBal.toDouble() : double.tryParse(rawBal.toString()) ?? 0.0);

      state = WalletState(
        balance: balance,
        transactions: transactions,
        isLoading: false,
      );
    } on Exception catch (_) {
      // Fallback to demo data
      if (state.transactions.isEmpty) {
        state = state.copyWith(
          transactions: TransactionModel.demoTransactions,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<Map<String, dynamic>> createOrder(double amount) async {
    final resp = await ApiClient.dio.post(
      ApiEndpoints.walletOrder,
      data: {'amount': amount},
    );
    return ApiClient.parseData(resp) as Map<String, dynamic>;
  }

  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await ApiClient.dio.post(
      ApiEndpoints.walletVerify,
      data: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      },
    );
    await fetchWallet(); // Refresh balance
  }

  Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final resp = await ApiClient.dio.post(
      ApiEndpoints.redeemPromo,
      data: {'code': code.trim().toUpperCase()},
    );
    final data = ApiClient.parseData(resp) as Map<String, dynamic>;
    await fetchWallet(); // Refresh balance after credit
    return data;
  }

  void updateBalance(double newBalance) {
    state = state.copyWith(balance: newBalance);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(),
);
