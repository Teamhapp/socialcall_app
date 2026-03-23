import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/app_snackbar.dart';

enum _LoginMode { otp, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

const _countryData = [
  ('🇮🇳', 'India', '+91'),
  ('🇺🇸', 'USA', '+1'),
  ('🇬🇧', 'UK', '+44'),
  ('🇦🇪', 'UAE', '+971'),
];

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading      = false;
  bool _obscurePass    = true;
  bool _phoneFocused   = false;
  bool _passwordFocused = false;
  String _countryCode  = '+91';
  _LoginMode _mode     = _LoginMode.otp;

  String get _countryFlag =>
      _countryData.firstWhere((c) => c.$3 == _countryCode,
          orElse: () => _countryData.first).$1;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  // ─── OTP flow ──────────────────────────────────────────────────────────────
  void _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (_phoneController.text.trim().length != 10) {
      _showSnack('Enter a valid 10-digit phone number');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(_fullPhone);
      if (mounted) context.go('/otp', extra: _fullPhone);
    } catch (e) {
      if (mounted) {
        _showSnack(
          e is Exception ? ApiClient.errorMessage(e as dynamic) : 'Failed to send OTP',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Password flow ─────────────────────────────────────────────────────────
  void _loginWithPassword() async {
    FocusScope.of(context).unfocus();
    if (_phoneController.text.trim().length != 10) {
      _showSnack('Enter a valid 10-digit phone number');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showSnack('Enter your password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).loginWithPassword(
        _fullPhone,
        _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        _showSnack(
          e is Exception ? ApiClient.errorMessage(e as dynamic) : 'Login failed',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnackBar.error(context, msg);
    } else {
      AppSnackBar.info(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOtp = _mode == _LoginMode.otp;

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

                // ── Logo & title ─────────────────────────────────────────────
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
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Welcome Back', style: AppTextStyles.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        isOtp
                            ? 'Enter your phone number to continue'
                            : 'Sign in with your phone & password',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Mode toggle ───────────────────────────────────────────────
                _ModeToggle(
                  current: _mode,
                  onChanged: (m) => setState(() {
                    _mode = m;
                    _passwordController.clear();
                  }),
                ),

                const SizedBox(height: 28),

                // ── Phone field ───────────────────────────────────────────────
                Text('Phone Number', style: AppTextStyles.labelLarge),
                const SizedBox(height: 12),
                Focus(
                  onFocusChange: (v) => setState(() => _phoneFocused = v),
                  child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _phoneFocused ? AppColors.primary : AppColors.border,
                      width: _phoneFocused ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Country code picker
                      GestureDetector(
                        onTap: _showCountryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: const BoxDecoration(
                            border: Border(
                                right: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text(_countryFlag,
                                  style: const TextStyle(fontSize: 20)),
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
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
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
                ),

                // ── Password field (password mode only) ───────────────────────
                if (!isOtp) ...[
                  const SizedBox(height: 20),
                  Text('Password', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 12),
                  Focus(
                    onFocusChange: (v) =>
                        setState(() => _passwordFocused = v),
                    child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _passwordFocused
                            ? AppColors.primary
                            : AppColors.border,
                        width: _passwordFocused ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loginWithPassword(),
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                        suffixIcon: GestureDetector(
                          onTap: () =>
                              setState(() => _obscurePass = !_obscurePass),
                          child: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Primary action button ─────────────────────────────────────
                GradientButton(
                  label: isOtp ? 'Send OTP' : 'Login',
                  onTap: isOtp ? _sendOtp : _loginWithPassword,
                  isLoading: _isLoading,
                ),

                // ── Register link (always visible) ───────────────────────
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/register'),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium,
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Create Account',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Terms ────────────────────────────────────────────────────
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

                const SizedBox(height: 40),

                // ── Divider ───────────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),

                const SizedBox(height: 20),

                // ── Become a host ─────────────────────────────────────────────
                GestureDetector(
                  onTap: () => context.go('/register'),
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

                const SizedBox(height: 40),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Country', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          ..._countryData.map((c) {
                final isSelected = _countryCode == c.$3;
                return GestureDetector(
                  onTap: () {
                    setState(() => _countryCode = c.$3);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppColors.primaryGradient
                          : null,
                      color: isSelected
                          ? null
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(c.$1,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            c.$2,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          c.$3,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isSelected
                                ? Colors.white70
                                : AppColors.textHint,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Mode toggle widget ───────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.current, required this.onChanged});

  final _LoginMode current;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'OTP Login',
            mode: _LoginMode.otp,
            current: current,
            onChanged: onChanged,
          ),
          _Tab(
            label: 'Password Login',
            mode: _LoginMode.password,
            current: current,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.mode,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final _LoginMode mode;
  final _LoginMode current;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: isActive ? Colors.white : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}
