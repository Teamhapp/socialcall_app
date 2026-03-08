import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gradient_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    if (_otpController.text.length != 4) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(
            widget.phone,
            _otpController.text,
          );
      // Connect socket after login
      await SocketService.connect();
      if (mounted) context.go('/home');
    } catch (e) {
      _otpController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('400') ? 'Invalid OTP. Try again.' : 'Verification failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 65,
      height: 65,
      textStyle: AppTextStyles.headingLarge,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: AppColors.textPrimary),
                  ),
                ),

                const SizedBox(height: 40),
                Text('Verify Phone', style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium,
                    children: [
                      const TextSpan(text: 'OTP sent to '),
                      TextSpan(
                        text: widget.phone,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // OTP input
                Center(
                  child: Pinput(
                    controller: _otpController,
                    length: 4,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(color: AppColors.primary),
                      ),
                    ),
                    onCompleted: (_) => _verifyOtp(),
                  ),
                ),

                const SizedBox(height: 32),

                // Resend timer
                Center(
                  child: _timerSeconds > 0
                      ? RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyMedium,
                            children: [
                              const TextSpan(text: 'Resend OTP in '),
                              TextSpan(
                                text: '${_timerSeconds}s',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: () async {
                            try {
                              await ref.read(authProvider.notifier).sendOtp(widget.phone);
                              // Only start countdown after OTP was successfully sent
                              _startTimer();
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to resend OTP. Try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text('Resend OTP',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.primary)),
                        ),
                ),

                const SizedBox(height: 48),

                GradientButton(
                  label: 'Verify & Continue',
                  onTap: _verifyOtp,
                  isLoading: _isLoading,
                ),

                const Spacer(),

                // Demo hint
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('OTP is sent to your phone number',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
