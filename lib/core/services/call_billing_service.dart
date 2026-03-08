// Handles per-minute wallet deduction during live calls

import 'dart:async';
import 'package:flutter/material.dart';

class CallBillingService {
  Timer? _timer;
  int _seconds = 0;
  double _totalCharged = 0;
  bool _lowBalanceWarned = false; // fire onLowBalance only once
  final double ratePerMinute;
  double walletBalance;

  // Callbacks
  final VoidCallback onLowBalance;     // < 1 minute left
  final VoidCallback onBalanceEmpty;   // force end call
  final Function(double charged, double balance) onTick;

  CallBillingService({
    required this.ratePerMinute,
    required this.walletBalance,
    required this.onTick,
    required this.onLowBalance,
    required this.onBalanceEmpty,
  });

  // ─── Start billing ──────────────────────────────────────────────────
  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;

      // Deduct every 60 seconds
      if (_seconds % 60 == 0) {
        _deduct();
      }

      // Warn at < 1 min remaining — fires only once
      final minutesLeft = (walletBalance / ratePerMinute);
      if (!_lowBalanceWarned && minutesLeft < 1 && minutesLeft > 0) {
        _lowBalanceWarned = true;
        onLowBalance();
      }
      if (walletBalance <= 0) {
        onBalanceEmpty();
        stop();
      }

      onTick(_totalCharged, walletBalance);
    });
  }

  void _deduct() {
    if (walletBalance >= ratePerMinute) {
      walletBalance -= ratePerMinute;
      _totalCharged += ratePerMinute;
    } else {
      _totalCharged += walletBalance;
      walletBalance = 0;
    }
  }

  // ─── Final charge for partial minute ────────────────────────────────
  double stop() {
    _timer?.cancel();
    final partial = (_seconds % 60) / 60 * ratePerMinute;
    if (partial > 0 && walletBalance > 0) {
      final charge = partial.clamp(0, walletBalance);
      _totalCharged += charge;
      walletBalance -= charge;
    }
    return _totalCharged;
  }

  int get elapsedSeconds => _seconds;
  double get totalCharged => _totalCharged;
}
