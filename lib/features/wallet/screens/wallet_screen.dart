import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../models/transaction_model.dart';
import '../../../shared/widgets/gradient_button.dart';

class WalletScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const WalletScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;
  late Razorpay _razorpay;

  final _rechargeAmounts = [49, 99, 199, 499, 999, 1999];
  int? _selectedAmount;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  // ─── Razorpay recharge ──────────────────────────────────────────────
  Future<void> _startRecharge(int amount) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _selectedAmount = amount;
    });

    try {
      final orderData =
          await ref.read(walletProvider.notifier).createOrder(amount.toDouble());
      final orderId = orderData['orderId'] as String;
      _pendingOrderId = orderId;

      // Dev mock: simulate payment for test orders
      if (orderId.startsWith('order_dev_')) {
        await ref.read(walletProvider.notifier).verifyPayment(
          orderId: orderId,
          paymentId: 'pay_dev_${DateTime.now().millisecondsSinceEpoch}',
          signature: 'dev_signature',
        );
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _selectedAmount = null;
          });
          _showSuccessSheet(amount);
        }
        return;
      }

      // Real Razorpay checkout
      final options = {
        'key': orderData['keyId'] ?? '',
        'order_id': orderId,
        'amount': amount * 100,
        'name': 'SocialCall',
        'description': 'Wallet Recharge',
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#6C63FF'},
      };
      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedAmount = null;
        });
        _showErrorSnack('Failed to initiate payment. Try again.');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final amount = _selectedAmount ?? 0;
    ref
        .read(walletProvider.notifier)
        .verifyPayment(
          orderId: response.orderId ?? _pendingOrderId ?? '',
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
        )
        .then((_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedAmount = null;
        });
        _showSuccessSheet(amount);
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedAmount = null;
        });
        _showErrorSnack('Payment verification failed. Contact support.');
      }
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _selectedAmount = null;
      });
      _showErrorSnack(response.message ?? 'Payment failed. Try again.');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _selectedAmount = null;
      });
    }
  }

  void _showSuccessSheet(int amount) {
    HapticFeedback.mediumImpact();
    final balance = ref.read(walletProvider).balance;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.callGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.callGreen, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Payment Successful!', style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.bodyMedium,
                children: [
                  const TextSpan(text: '₹'),
                  TextSpan(
                    text: '$amount',
                    style: AppTextStyles.headingLarge
                        .copyWith(color: AppColors.callGreen),
                  ),
                  const TextSpan(text: ' has been added\nto your wallet'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New balance: ₹${balance.toStringAsFixed(2)}',
              style:
                  AppTextStyles.labelMedium.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Great!',
              height: 50,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.callRed,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Custom amount dialog ───────────────────────────────────────────
  void _showCustomAmountDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Enter Amount', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Minimum ₹10', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.headingMedium
                  .copyWith(color: AppColors.primary),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '500',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(ctrl.text) ?? 0;
              if (amount >= 10) {
                Navigator.pop(context);
                _startRecharge(amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Minimum recharge amount is ₹10'),
                  ),
                );
              }
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('My Wallet'),
              backgroundColor: AppColors.background,
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(walletProvider.notifier).fetchWallet(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Balance card ───────────────────────────────────
                _BalanceCard(
                  balance: walletState.balance,
                  shimmerAnim: _shimmerAnim,
                ),

                // ─── Quick recharge ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Add Money',
                              style: AppTextStyles.headingSmall),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.callGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.callGreen
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded,
                                    size: 10, color: AppColors.callGreen),
                                const SizedBox(width: 4),
                                Text('Secured by Razorpay',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.callGreen)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Amount grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _rechargeAmounts.length,
                        itemBuilder: (_, i) => _RechargeChip(
                          amount: _rechargeAmounts[i],
                          isSelected:
                              _selectedAmount == _rechargeAmounts[i],
                          isLoading: _isProcessing &&
                              _selectedAmount == _rechargeAmounts[i],
                          onTap: _isProcessing
                              ? null
                              : () => _startRecharge(_rechargeAmounts[i]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Custom amount button
                      GradientButton(
                        label: _isProcessing
                            ? 'Processing...'
                            : 'Enter Custom Amount',
                        height: 48,
                        isLoading:
                            _isProcessing && _selectedAmount == null,
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                        onTap:
                            _isProcessing ? null : _showCustomAmountDialog,
                      ),

                      const SizedBox(height: 8),
                      _PaymentMethodsRow(),
                      const SizedBox(height: 28),
                      _HowItWorks(rateExample: 15),
                      const SizedBox(height: 28),

                      // ─── Transactions ───────────────────────────────
                      Row(
                        children: [
                          Text('Recent Transactions',
                              style: AppTextStyles.headingSmall),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (walletState.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (walletState.transactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No transactions yet',
                                style: AppTextStyles.bodyMedium),
                          ),
                        )
                      else
                        ...walletState.transactions
                            .map((t) => _TransactionTile(transaction: t)),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double balance;
  final Animation<double> shimmerAnim;

  const _BalanceCard({required this.balance, required this.shimmerAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text('Wallet Balance',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white70)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text('Active',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: shimmerAnim,
            builder: (_, __) => Text(
              '₹${balance.toStringAsFixed(2)}',
              style: AppTextStyles.amount,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            balance > 30
                ? 'Ready to use • ~${(balance / 15).toStringAsFixed(0)} min of audio calls'
                : '⚠️  Low balance — add money to continue calls',
            style: AppTextStyles.caption.copyWith(
              color: balance > 30 ? Colors.white60 : Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (balance / 2000).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹0',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white60)),
              Text('₹2,000 max',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RechargeChip extends StatelessWidget {
  final int amount;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;

  const _RechargeChip({
    required this.amount,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  '₹$amount',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PaymentMethodsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final methods = [
      ('UPI', Icons.qr_code_rounded),
      ('Cards', Icons.credit_card_rounded),
      ('NetBanking', Icons.account_balance_rounded),
      ('Wallets', Icons.wallet_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: methods
            .map((m) => Column(
                  children: [
                    Icon(m.$2, size: 20, color: AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(m.$1, style: AppTextStyles.caption),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final int rateExample;
  const _HowItWorks({required this.rateExample});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('How Billing Works',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            ('💰', 'Add money to your wallet before starting a call'),
            ('⏱️', 'Wallet deducts ₹$rateExample for every minute of call'),
            ('🔔', 'You\'ll be warned when balance drops below 1 minute'),
            ('🛡️', 'Unused balance stays safe in your wallet forever'),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.$2,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionTile({required this.transaction});

  IconData get _icon => switch (transaction.type) {
        TransactionType.recharge => Icons.add_circle_rounded,
        TransactionType.call => Icons.call_rounded,
        TransactionType.gift => Icons.card_giftcard_rounded,
        TransactionType.payout => Icons.upload_rounded,
      };

  Color get _iconColor => switch (transaction.type) {
        TransactionType.recharge => AppColors.callGreen,
        TransactionType.call => AppColors.primary,
        TransactionType.gift => AppColors.accent,
        TransactionType.payout => AppColors.warning,
      };

  String get _typeLabel => switch (transaction.type) {
        TransactionType.recharge => 'Recharge',
        TransactionType.call => 'Call',
        TransactionType.gift => 'Gift',
        TransactionType.payout => 'Payout',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.description,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_typeLabel,
                          style: AppTextStyles.caption
                              .copyWith(color: _iconColor)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMM, hh:mm a')
                          .format(transaction.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isCredit ? '+' : '-'}₹${transaction.amount.toInt()}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: transaction.isCredit
                      ? AppColors.callGreen
                      : AppColors.callRed,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.callGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
