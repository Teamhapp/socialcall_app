// lib/core/services/wallet_service.dart
// Connects Razorpay checkout → backend verification → local balance update

import 'dart:math';
import 'package:flutter/material.dart';
import 'razorpay_service.dart';

class WalletService {
  final RazorpayService _razorpay = RazorpayService();

  // ─── Simulate creating an order on your backend ─────────────────────
  // In production replace with: await dio.post('/api/wallet/recharge', data:{amount})
  Future<String> _createOrder(int amount) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Returns a fake order ID — your real backend returns a Razorpay order_id
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'order_demo_$rand';
  }

  // ─── Simulate backend payment verification ───────────────────────────
  // In production: await dio.post('/api/wallet/verify', data:{paymentId, orderId, signature})
  Future<bool> _verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true; // backend HMAC verification
  }

  // ─── Main recharge flow ──────────────────────────────────────────────
  Future<void> initiateRecharge({
    required BuildContext context,
    required int amount,
    required String razorpayKeyId,
    required Function(int amount) onSuccess,
    required Function(String error) onFailure,
  }) async {
    _razorpay.init();

    // Step 1 — Create order on backend
    String orderId;
    try {
      orderId = await _createOrder(amount);
    } catch (e) {
      onFailure('Could not connect to server. Please try again.');
      return;
    }

    // Step 2 — Open Razorpay checkout
    _razorpay.openPayment(
      amountInPaise: amount * 100,
      userPhone: '9876543210',    // pull from user session in production
      userEmail: 'user@example.com',
      userName: 'User',
      orderId: orderId,
      razorpayKeyId: razorpayKeyId,
      onResult: (result) async {
        if (result.success) {
          // Step 3 — Verify payment on backend
          final verified = await _verifyPayment(
            paymentId: result.paymentId ?? '',
            orderId: result.orderId ?? orderId,
            signature: result.signature ?? '',
          );
          if (verified) {
            onSuccess(amount);
          } else {
            onFailure('Payment verification failed. Contact support.');
          }
        } else {
          if (result.errorMessage != null &&
              !result.errorMessage!.contains('cancelled')) {
            onFailure(result.errorMessage!);
          }
        }
        _razorpay.dispose();
      },
    );
  }
}
