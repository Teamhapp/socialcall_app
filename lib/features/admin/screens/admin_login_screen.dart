import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/admin_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pwd = _passwordCtrl.text.trim();
    if (pwd.isEmpty) {
      AppSnackBar.error(context, 'Enter admin password');
      return;
    }
    final ok = await ref.read(adminProvider.notifier).login(pwd);
    if (!mounted) return;
    if (ok) {
      context.go('/admin');
    } else {
      final err = ref.read(adminProvider).error ?? 'Login failed';
      AppSnackBar.error(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(adminProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield icon
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Admin Panel', style: AppTextStyles.headingLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter your admin password to continue',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Password field
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: AppTextStyles.bodyLarge,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle:
                        AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                GradientButton(
                  label: 'Enter Admin Panel',
                  isLoading: loading,
                  onTap: _login,
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Back to settings',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textHint),
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
