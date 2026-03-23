import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';

class AdminPushScreen extends StatefulWidget {
  const AdminPushScreen({super.key});

  @override
  State<AdminPushScreen> createState() => _AdminPushScreenState();
}

class _AdminPushScreenState extends State<AdminPushScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _target = 'all';
  bool _sending = false;

  static const _targets = [
    ('all', 'All Users', Icons.people_rounded),
    ('hosts', 'Hosts Only', Icons.headset_mic_rounded),
    ('callers', 'Callers Only', Icons.person_rounded),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      AppSnackBar.error(context, 'Title and message are required');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Send Broadcast', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: ${_targets.firstWhere((t) => t.$1 == _target).$2}',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 6),
            Text(title,
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(body, style: AppTextStyles.bodySmall),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Send',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await AdminApi.post(
        ApiEndpoints.adminPush,
        data: {
          'title': title,
          'body': body,
          'target': _target,
        },
      );
      if (mounted) {
        AppSnackBar.success(context, 'Notification sent!');
        _titleCtrl.clear();
        _bodyCtrl.clear();
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Push Notifications', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target selector
            Text('Target Audience', style: AppTextStyles.labelLarge),
            const SizedBox(height: 12),
            ..._targets.map((t) => GestureDetector(
                  onTap: () => setState(() => _target = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: _target == t.$1
                          ? AppColors.primaryGradient
                          : null,
                      color: _target == t.$1 ? null : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _target == t.$1
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(t.$3,
                            color: _target == t.$1
                                ? Colors.white
                                : AppColors.textHint,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(t.$2,
                            style: AppTextStyles.bodyLarge.copyWith(
                                color: _target == t.$1
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                        const Spacer(),
                        if (_target == t.$1)
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 24),

            // Title
            Text('Notification Title', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: AppTextStyles.bodyMedium,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'e.g. New feature available!',
                hintStyle:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: AppTextStyles.caption,
              ),
            ),

            const SizedBox(height: 16),

            // Body
            Text('Message Body', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              style: AppTextStyles.bodyMedium,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Write your message here…',
                hintStyle:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: AppTextStyles.caption,
              ),
            ),

            const SizedBox(height: 28),

            GradientButton(
              label: 'Send Broadcast',
              isLoading: _sending,
              onTap: _send,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
