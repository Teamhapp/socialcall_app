import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gradient_button.dart';

class BecomeHostScreen extends ConsumerStatefulWidget {
  const BecomeHostScreen({super.key});

  @override
  ConsumerState<BecomeHostScreen> createState() => _BecomeHostScreenState();
}

class _BecomeHostScreenState extends ConsumerState<BecomeHostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _audioRateCtrl = TextEditingController(text: '15');
  final _videoRateCtrl = TextEditingController(text: '40');
  final _tagCtrl = TextEditingController();

  bool _isSubmitting = false;
  final Set<String> _selectedLanguages = {'Hindi'};
  final List<String> _tags = [];

  static const _languageOptions = [
    'Hindi', 'English', 'Tamil', 'Telugu',
    'Kannada', 'Bengali', 'Marathi', 'Gujarati',
  ];

  @override
  void dispose() {
    _bioCtrl.dispose();
    _audioRateCtrl.dispose();
    _videoRateCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLanguages.isEmpty) {
      _showError('Select at least one language.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiClient.dio.post(
        ApiEndpoints.hostProfile,
        data: {
          'bio': _bioCtrl.text.trim(),
          'languages': _selectedLanguages.toList(),
          'tags': _tags,
          'audioRate': double.parse(_audioRateCtrl.text),
          'videoRate': double.parse(_videoRateCtrl.text),
        },
      );
      // Refresh user profile so isHost = true is reflected everywhere.
      await ref.read(authProvider.notifier).refreshBalance();
      if (mounted) {
        _showSuccessDialog();
      }
    } on DioException catch (e) {
      if (mounted) _showError(ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.callRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.callGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.callGreen, size: 44),
            ),
            const SizedBox(height: 20),
            Text('You\'re Live! 🎉',
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'You\'re now online and ready to receive calls.\nYou\'ll go offline when you close the app.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Go to Dashboard',
              height: 50,
              onTap: () {
                Navigator.pop(context);
                context.go('/host-dashboard');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 8) return;
    setState(() {
      _tags.add(tag);
      _tagCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
        ),
        title: Text('Become a Host', style: AppTextStyles.headingMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Hero banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Earn while talking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            )),
                        SizedBox(height: 4),
                        Text('Set your own rates and\nwork on your schedule.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            )),
                      ],
                    ),
                  ),
                  const Icon(Icons.headset_mic_rounded,
                      color: Colors.white70, size: 48),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Bio ───────────────────────────────────────────────────────
            _SectionLabel('About You'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 500,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Tell callers about yourself, your interests, expertise...',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 20) {
                  return 'Write at least 20 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Languages ─────────────────────────────────────────────────
            _SectionLabel('Languages You Speak'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languageOptions.map((lang) {
                final selected = _selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(lang),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedLanguages.add(lang);
                    } else if (_selectedLanguages.length > 1) {
                      _selectedLanguages.remove(lang);
                    }
                  }),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.card,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Tags / Interests ──────────────────────────────────────────
            _SectionLabel('Tags / Interests (optional)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    style: AppTextStyles.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Fitness, Cooking, Tech...',
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.primary, size: 28),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _tags
                    .map((t) => Chip(
                          label: Text(t, style: AppTextStyles.caption),
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.border),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _tags.remove(t)),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 24),

            // ── Rates ─────────────────────────────────────────────────────
            _SectionLabel('Call Rates (₹ per minute)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RateField(
                    label: '📞 Audio',
                    controller: _audioRateCtrl,
                    hint: '₹15',
                    min: 5,
                    max: 500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RateField(
                    label: '📹 Video',
                    controller: _videoRateCtrl,
                    hint: '₹40',
                    min: 10,
                    max: 1000,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Earnings info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You keep 65% of every call. Platform takes 35% for infrastructure & support.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            GradientButton(
              label: _isSubmitting ? 'Creating Profile...' : 'Create Host Profile',
              isLoading: _isSubmitting,
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 20),
              onTap: _isSubmitting ? null : _submit,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
      );
}

class _RateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final double min;
  final double max;

  const _RateField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary),
          decoration: InputDecoration(hintText: hint),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n < min || n > max) {
              return '₹$min–$max';
            }
            return null;
          },
        ),
      ],
    );
  }
}
