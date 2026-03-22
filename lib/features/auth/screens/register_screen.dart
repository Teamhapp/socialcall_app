import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/gender_picker.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _isLoading   = false;
  bool _obscurePass = true;
  bool _obscureConf = true;
  String _countryCode = '+91';
  String? _selectedGender;

  // (flag, name, dialCode)
  static const _countryData = [
    ('🇮🇳', 'India',          '+91'),
    ('🇺🇸', 'United States',  '+1'),
    ('🇬🇧', 'United Kingdom', '+44'),
    ('🇦🇪', 'UAE',            '+971'),
    ('🇸🇬', 'Singapore',      '+65'),
    ('🇦🇺', 'Australia',      '+61'),
    ('🇨🇦', 'Canada',         '+1'),
    ('🇩🇪', 'Germany',        '+49'),
    ('🇿🇦', 'South Africa',   '+27'),
    ('🇳🇬', 'Nigeria',        '+234'),
  ];

  String get _countryFlag =>
      _countryData.firstWhere((c) => c.$3 == _countryCode,
          orElse: () => _countryData.first).$1;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  void _register() async {
    final phone    = _phoneController.text.trim();
    final name     = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmController.text;

    if (phone.length != 10) {
      _showSnack('Enter a valid 10-digit phone number');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).register(
        _fullPhone,
        password,
        name: name.isEmpty ? null : name,
        gender: _selectedGender,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        _showSnack(
          e is Exception ? ApiClient.errorMessage(e as dynamic) : 'Registration failed',
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Back button row ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => context.go('/login'),
                  ),
                ),
              ),

              // ── Scrollable form ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Header
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
                                Icons.person_add_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Create Account',
                                style: AppTextStyles.displayMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Register with your phone & password',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Name field (optional) ─────────────────────────────
                      Text('Full Name (optional)',
                          style: AppTextStyles.labelLarge),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: AppTextStyles.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppColors.textHint,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Phone field ───────────────────────────────────────
                      Text('Phone Number', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _showCountryPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      right:
                                          BorderSide(color: AppColors.border)),
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

                      const SizedBox(height: 20),

                      // ── Password field ────────────────────────────────────
                      Text('Password', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        controller: _passwordController,
                        hintText: 'Min. 6 characters',
                        obscure: _obscurePass,
                        onToggle: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),

                      const SizedBox(height: 20),

                      // ── Confirm password field ────────────────────────────
                      Text('Confirm Password', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        controller: _confirmController,
                        hintText: 'Re-enter password',
                        obscure: _obscureConf,
                        onToggle: () =>
                            setState(() => _obscureConf = !_obscureConf),
                      ),

                      const SizedBox(height: 20),

                      // ── Gender (optional) ─────────────────────────────────
                      Text('Gender (optional)', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 12),
                      GenderPicker(
                        selected: _selectedGender,
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),

                      const SizedBox(height: 32),

                      // ── Register button ───────────────────────────────────
                      GradientButton(
                        label: 'Create Account',
                        onTap: _register,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 16),

                      // ── Login link ────────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => context.go('/login'),
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.bodyMedium,
                              children: [
                                const TextSpan(
                                    text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Login',
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

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textHint,
              size: 20,
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
          ..._countryData.map((c) => ListTile(
                leading: Text(c.$1, style: const TextStyle(fontSize: 24)),
                title: Text(c.$2, style: AppTextStyles.bodyLarge),
                trailing: Text(c.$3, style: AppTextStyles.bodyMedium),
                onTap: () {
                  setState(() => _countryCode = c.$3);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
