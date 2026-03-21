import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ReportDialog extends StatefulWidget {
  final String targetType; // 'host' | 'message' | 'call'
  final String targetId;
  final String? targetName;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetName,
  });

  /// Convenience method to show as bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? targetName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportDialog(
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const _reasons = [
    ('inappropriate', 'Inappropriate Behavior'),
    ('fake_profile', 'Fake Profile'),
    ('spam', 'Spam'),
    ('harassment', 'Harassment'),
    ('other', 'Other'),
  ];

  String? _selectedReason;
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiClient.dio.post(ApiEndpoints.submitReport, data: {
        'targetType': widget.targetType,
        'targetId': widget.targetId,
        'reason': _selectedReason,
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Our team will review it shortly.'),
            backgroundColor: AppColors.callGreen,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.callRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report ${widget.targetName ?? widget.targetType}',
                  style: AppTextStyles.headingSmall,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Help us keep this platform safe. Reports are anonymous.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          // Reason list
          ..._reasons.map((r) {
            final (value, label) = r;
            return RadioListTile<String>(
              value: value,
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              title: Text(label, style: AppTextStyles.bodyMedium),
              activeColor: AppColors.primary,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),

          const SizedBox(height: 8),

          // Optional description
          TextField(
            controller: _descController,
            maxLines: 3,
            maxLength: 500,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: AppTextStyles.caption,
            ),
          ),

          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.callRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Report',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
