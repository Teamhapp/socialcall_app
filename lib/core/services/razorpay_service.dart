import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final int amount;

  const PaymentResult({
    required this.success,
    required this.amount,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
  });
}

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  /// Key is passed in from the backend response, so no hardcoded key here.
  /// The wallet_screen.dart passes orderData['keyId'] which comes from the
  /// backend's RAZORPAY_KEY_ID env variable.
  Razorpay? _razorpay;
  Function(PaymentResult)? _onResult;

  // ─── Initialize ────────────────────────────────────────────────────
  void init() {
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ─── Open Payment Sheet ─────────────────────────────────────────────
  void openPayment({
    required int amountInPaise,      // Razorpay works in paise (₹1 = 100 paise)
    required String userPhone,
    required String userEmail,
    required String userName,
    required String orderId,         // from your backend
    required String razorpayKeyId,   // passed from backend API response
    required Function(PaymentResult) onResult,
  }) {
    _onResult = onResult;

    final options = {
      'key': razorpayKeyId,  // key comes from backend (RAZORPAY_KEY_ID env var)
      'amount': amountInPaise,
      'name': 'SocialCall',
      'order_id': orderId,
      'description': 'Wallet Recharge',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'external': {
        'wallets': ['paytm', 'amazonpay'],
      },
      'theme': {
        'color': '#FF4D79',             // Brand pink color
      },
      'retry': {
        'enabled': true,
        'max_count': 2,
      },
      'timeout': 300,                   // 5 minutes
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      onResult(PaymentResult(
        success: false,
        amount: amountInPaise ~/ 100,
        errorMessage: e.toString(),
      ));
    }
  }

  // ─── Handlers ──────────────────────────────────────────────────────
  void _handleSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Payment success: ${response.paymentId}');
    _onResult?.call(PaymentResult(
      success: true,
      amount: 0, // amount is tracked from options
      paymentId: response.paymentId,
      orderId: response.orderId,
      signature: response.signature,
    ));
  }

  void _handleError(PaymentFailureResponse response) {
    debugPrint('❌ Payment failed: ${response.message}');
    _onResult?.call(PaymentResult(
      success: false,
      amount: 0,
      errorMessage: response.message ?? 'Payment failed',
    ));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('👛 External wallet: ${response.walletName}');
  }

  // ─── Cleanup ────────────────────────────────────────────────────────
  void dispose() {
    _razorpay?.clear();
  }
}
