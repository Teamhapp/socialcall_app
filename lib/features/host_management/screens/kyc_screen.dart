import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gradient_button.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _kycData;
  String _selectedDocType = 'aadhaar';
  File? _frontImage;
  File? _backImage;
  File? _selfieImage;
  final _picker = ImagePicker();

  final _docTypes = [
    ('aadhaar', '🪪', 'Aadhaar Card'),
    ('pan', '🃏', 'PAN Card'),
    ('passport', '📘', 'Passport'),
    ('driving_license', '🚗', 'Driving License'),
  ];

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.kycStatus);
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      if (mounted) setState(() { _kycData = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(String field) async {
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      if (field == 'front')  _frontImage  = file;
      if (field == 'back')   _backImage   = file;
      if (field == 'selfie') _selfieImage = file;
    });
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: Text('Take Photo', style: AppTextStyles.bodyLarge),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('Choose from Gallery', style: AppTextStyles.bodyLarge),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitKyc() async {
    if (_frontImage == null) {
      _showSnack('Please upload the front side of your document', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formData = FormData.fromMap({
        'document_type': _selectedDocType,
        'front': await MultipartFile.fromFile(
          _frontImage!.path,
          filename: 'front.jpg',
        ),
        if (_backImage != null)
          'back': await MultipartFile.fromFile(
            _backImage!.path,
            filename: 'back.jpg',
          ),
        if (_selfieImage != null)
          'selfie': await MultipartFile.fromFile(
            _selfieImage!.path,
            filename: 'selfie.jpg',
          ),
      });

      await ApiClient.dio.post(
        ApiEndpoints.kycSubmit,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      _showSnack('KYC submitted! We\'ll review within 24 hours.');
      await _loadKycStatus();
    } on DioException catch (e) {
      _showSnack(ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.callRed : AppColors.callGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Identity Verification', style: AppTextStyles.headingMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = _kycData?['kyc_status'] as String? ?? 'not_submitted';

    // Already approved
    if (status == 'approved') return _buildApprovedView();

    // Pending review
    if (status == 'pending') return _buildPendingView();

    // Rejected — show reason and allow resubmission
    if (status == 'rejected') return _buildRejectedView();

    // Not submitted — show form
    return _buildSubmissionForm();
  }

  Widget _buildApprovedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.callGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppColors.callGreen, size: 60),
            ),
            const SizedBox(height: 24),
            Text('KYC Verified!', style: AppTextStyles.headingLarge),
            const SizedBox(height: 8),
            Text(
              'Your identity has been verified. You can now receive payouts.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.warning, size: 60),
            ),
            const SizedBox(height: 24),
            Text('Under Review', style: AppTextStyles.headingLarge),
            const SizedBox(height: 8),
            Text(
              'Your KYC documents have been submitted and are being reviewed. This usually takes up to 24 hours.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _loadKycStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView() {
    final submission = _kycData?['submission'] as Map<String, dynamic>?;
    final reason = submission?['rejection_reason'] as String? ?? 'Document unclear or invalid';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.callRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.callRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.callRed, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KYC Rejected', style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.callRed)),
                      const SizedBox(height: 4),
                      Text(reason, style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Resubmit Documents', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text('Please fix the issue and upload clear, valid documents.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _buildSubmissionForm(isResubmit: true),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm({bool isResubmit = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          if (!isResubmit) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verify your identity to unlock payouts and build trust with callers.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Document type
          Text('Document Type', style: AppTextStyles.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _docTypes.map((dt) {
              final selected = _selectedDocType == dt.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedDocType = dt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dt.$2, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(dt.$3,
                          style: AppTextStyles.labelMedium.copyWith(
                              color: selected ? Colors.white : AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          Text('Upload Documents', style: AppTextStyles.labelLarge),
          const SizedBox(height: 4),
          Text('Upload clear photos of your document. Max 5MB each.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Front image
          _ImageUploadCard(
            label: 'Front Side *',
            hint: 'Take a clear photo of the front',
            image: _frontImage,
            onTap: () => _pickImage('front'),
            required: true,
          ),
          const SizedBox(height: 12),

          // Back image (optional for passport)
          _ImageUploadCard(
            label: 'Back Side (optional)',
            hint: 'Back of the document',
            image: _backImage,
            onTap: () => _pickImage('back'),
          ),
          const SizedBox(height: 12),

          // Selfie with document
          _ImageUploadCard(
            label: 'Selfie with Document (optional)',
            hint: 'Hold the document next to your face',
            image: _selfieImage,
            onTap: () => _pickImage('selfie'),
            icon: Icons.selfie_rounded,
          ),

          const SizedBox(height: 32),

          GradientButton(
            label: _isSubmitting ? 'Submitting...' : 'Submit for Verification',
            height: 54,
            isLoading: _isSubmitting,
            icon: _isSubmitting
                ? null
                : const Icon(Icons.upload_rounded, color: Colors.white, size: 20),
            onTap: _isSubmitting ? null : _submitKyc,
          ),

          const SizedBox(height: 16),
          Text(
            'Your documents are encrypted and used only for identity verification. They will not be shared with third parties.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Image upload card ──────────────────────────────────────────────────────────
class _ImageUploadCard extends StatelessWidget {
  final String label;
  final String hint;
  final File? image;
  final VoidCallback onTap;
  final bool required;
  final IconData icon;

  const _ImageUploadCard({
    required this.label,
    required this.hint,
    required this.image,
    required this.onTap,
    this.required = false,
    this.icon = Icons.add_photo_alternate_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: image != null ? AppColors.primary : AppColors.border,
            width: image != null ? 2 : 1.5,
            style: image != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.callGreen, size: 14),
                            const SizedBox(width: 4),
                            Text(label,
                                style: AppTextStyles.caption
                                    .copyWith(color: Colors.white)),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_rounded,
                                color: Colors.white70, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textHint, size: 36),
                  const SizedBox(height: 8),
                  Text(label,
                      style: AppTextStyles.labelMedium.copyWith(
                          color: required ? AppColors.primary : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(hint,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
      ),
    );
  }
}
