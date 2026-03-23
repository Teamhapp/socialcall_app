import 'package:flutter/material.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../widgets/admin_empty_state.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  List<AdminOffer> _offers = [];
  bool _loading = true;

  static const _colorPresets = [
    ('#FF4D79', 'Pink'),
    ('#7B61FF', 'Purple'),
    ('#FF9500', 'Orange'),
    ('#00C7A4', 'Teal'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApi.get(ApiEndpoints.adminOffers);
      final list = AdminApi.parseData(res) as List<dynamic>;
      setState(() {
        _offers = list
            .map((e) => AdminOffer.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.error(context, AdminApi.errorMessage(e));
      }
    }
  }

  Future<void> _toggleActive(AdminOffer offer) async {
    if (offer.isActive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Deactivate Offer', style: AppTextStyles.headingSmall),
          content: Text(
            'Deactivate "${offer.title}"? It will disappear from the home screen.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textHint))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Deactivate',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.callRed))),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    try {
      await AdminApi.patch(
        ApiEndpoints.adminOffer(offer.id),
        data: {'is_active': !offer.isActive},
      );
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final promoCtrl = TextEditingController();
    final ctaCtrl = TextEditingController(text: 'Claim Now');
    String emoji = '🎉';
    String colorHex = '#FF4D79';
    DateTime? endsAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('New Offer', style: AppTextStyles.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(titleCtrl, 'Title *', hint: 'e.g. Weekend Special'),
                const SizedBox(height: 10),
                _field(subtitleCtrl, 'Subtitle', hint: 'e.g. 20% extra coins'),
                const SizedBox(height: 10),
                _field(promoCtrl, 'Promo Code (optional)',
                    hint: 'e.g. WEEKEND20',
                    caps: TextCapitalization.characters),
                const SizedBox(height: 10),
                _field(ctaCtrl, 'CTA Label', hint: 'Claim Now'),
                const SizedBox(height: 10),
                Text('Emoji Icon', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setSt(() => emoji = v.trim().isEmpty ? '🎉' : v.trim()),
                  decoration: InputDecoration(
                    hintText: '🎉',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Background Color', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _colorPresets.map((p) {
                    final hex = p.$1;
                    final label = p.$2;
                    final selected = colorHex == hex;
                    final color = _hexToColor(hex);
                    return GestureDetector(
                      onTap: () => setSt(() => colorHex = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : Tooltip(message: label, child: const SizedBox()),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text('Ends At *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSt(() => endsAt = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Text(
                          endsAt == null
                              ? 'Pick end date'
                              : '${endsAt!.year}-${endsAt!.month.toString().padLeft(2, '0')}-${endsAt!.day.toString().padLeft(2, '0')}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: endsAt == null
                                  ? AppColors.textHint
                                  : AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || endsAt == null) {
                  AppSnackBar.error(ctx, 'Title and end date are required');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await AdminApi.post(ApiEndpoints.adminOffers, data: {
                    'title': titleCtrl.text.trim(),
                    'subtitle': subtitleCtrl.text.trim().isEmpty
                        ? null
                        : subtitleCtrl.text.trim(),
                    'bg_color_hex': colorHex,
                    'icon_emoji': emoji,
                    'cta_label': ctaCtrl.text.trim().isEmpty
                        ? 'Claim Now'
                        : ctaCtrl.text.trim(),
                    'promo_code': promoCtrl.text.trim().isEmpty
                        ? null
                        : promoCtrl.text.trim().toUpperCase(),
                    'ends_at': endsAt!.toIso8601String(),
                  });
                  if (mounted) AppSnackBar.success(context, 'Offer created!');
                  _load();
                } catch (e) {
                  if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Deals'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.local_activity_outlined,
                  message: 'No offers yet.\nTap + to create one.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final o = _offers[i];
                      final color = _hexToColor(o.bgColorHex);
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(o.iconEmoji,
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          title: Text(o.title,
                              style: AppTextStyles.bodyLarge
                                  .copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (o.subtitle != null)
                                Text(o.subtitle!,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textHint)),
                              if (o.promoCode != null)
                                Text('Code: ${o.promoCode}',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700)),
                              Text(
                                'Ends: ${o.endsAt.split('T').first}',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textHint),
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: o.isActive,
                            activeThumbColor: AppColors.primary,
                            onChanged: (_) => _toggleActive(o),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          textCapitalization: caps,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
