import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/gradient_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _countryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }
    final phone = '$_countryCode${_phoneController.text}';
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (mounted) context.go('/otp', extra: phone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Exception ? ApiClient.errorMessage(e as dynamic) : 'Failed to send OTP'),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Logo & title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text('Welcome Back', style: AppTextStyles.displayMedium),
                      const SizedBox(height: 8),
                      Text('Enter your phone number to continue',
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),

                const SizedBox(height: 56),

                Text('Phone Number', style: AppTextStyles.labelLarge),
                const SizedBox(height: 12),

                // Phone input
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Country code picker
                      GestureDetector(
                        onTap: () => _showCountryPicker(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: const BoxDecoration(
                            border: Border(
                                right: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text('🇮🇳', style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text(_countryCode,
                                  style: AppTextStyles.bodyLarge),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more,
                                  color: AppColors.textHint, size: 18),
                            ],
                          ),
                        ),
                      ),
                      // Number field
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: AppTextStyles.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: '98765 43210',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                GradientButton(
                  label: 'Send OTP',
                  onTap: _sendOtp,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Terms
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.caption,
                      children: [
                        const TextSpan(text: 'By continuing you agree to our '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.primary),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Divider
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),

                const SizedBox(height: 20),

                // Become a host
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Become a Host & Earn Money',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Country', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          ...[
            ('🇮🇳', 'India', '+91'),
            ('🇺🇸', 'USA', '+1'),
            ('🇬🇧', 'UK', '+44'),
            ('🇦🇪', 'UAE', '+971'),
          ].map((c) => ListTile(
            leading: Text(c.$1, style: const TextStyle(fontSize: 24)),
            title: Text(c.$2, style: AppTextStyles.bodyLarge),
            trailing: Text(c.$3, style: AppTextStyles.bodyMedium),
            onTap: () {
              setState(() => _countryCode = c.$3);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }
}
