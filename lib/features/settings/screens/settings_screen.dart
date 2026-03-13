import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Notification toggles
  bool _callNotifications = true;
  bool _messageNotifications = true;
  bool _giftNotifications = true;
  bool _promoNotifications = false;

  // Call preferences
  bool _autoAnswer = false;
  bool _showCallTimer = true;
  bool _lowBalanceAlert = true;
  String _callQuality = 'Auto';

  // Privacy
  bool _showOnlineStatus = true;
  bool _allowGifts = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

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
        title: Text('Settings', style: AppTextStyles.headingMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: ListView(
        children: [
          // ── Account ───────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_rounded,
            label: 'Edit Profile',
            subtitle: user?.name ?? 'Update your name & photo',
            onTap: () => _showEditNameDialog(context),
          ),
          _SettingsTile(
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            subtitle: user?.phone ?? '',
            trailing: const _Badge(text: 'Verified', color: AppColors.online),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'Language',
            subtitle: 'English',
            onTap: () => _showLanguagePicker(context),
          ),

          // ── Notifications ─────────────────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          _ToggleTile(
            icon: Icons.call_rounded,
            label: 'Incoming Calls',
            subtitle: 'Alert when someone calls you',
            value: _callNotifications,
            onChanged: (v) => setState(() => _callNotifications = v),
          ),
          _ToggleTile(
            icon: Icons.chat_bubble_rounded,
            label: 'Messages',
            subtitle: 'New message notifications',
            value: _messageNotifications,
            onChanged: (v) => setState(() => _messageNotifications = v),
          ),
          _ToggleTile(
            icon: Icons.card_giftcard_rounded,
            label: 'Gifts',
            subtitle: 'When someone sends you a gift',
            value: _giftNotifications,
            onChanged: (v) => setState(() => _giftNotifications = v),
          ),
          _ToggleTile(
            icon: Icons.local_offer_rounded,
            label: 'Offers & Promotions',
            subtitle: 'Wallet recharge offers',
            value: _promoNotifications,
            onChanged: (v) => setState(() => _promoNotifications = v),
          ),

          // ── Call Preferences ──────────────────────────────────────────
          _SectionHeader(title: 'Call Preferences'),
          _ToggleTile(
            icon: Icons.timer_rounded,
            label: 'Show Call Timer',
            subtitle: 'Display duration during calls',
            value: _showCallTimer,
            onChanged: (v) => setState(() => _showCallTimer = v),
          ),
          _ToggleTile(
            icon: Icons.warning_amber_rounded,
            label: 'Low Balance Alert',
            subtitle: 'Warn when balance < 1 minute',
            value: _lowBalanceAlert,
            onChanged: (v) => setState(() => _lowBalanceAlert = v),
          ),
          _SettingsTile(
            icon: Icons.high_quality_rounded,
            label: 'Call Quality',
            subtitle: _callQuality,
            onTap: () => _showQualityPicker(context),
          ),

          // ── Privacy ───────────────────────────────────────────────────
          _SectionHeader(title: 'Privacy'),
          _ToggleTile(
            icon: Icons.visibility_rounded,
            label: 'Show Online Status',
            subtitle: 'Let others see when you\'re online',
            value: _showOnlineStatus,
            onChanged: (v) => setState(() => _showOnlineStatus = v),
          ),
          _ToggleTile(
            icon: Icons.card_giftcard_rounded,
            label: 'Allow Gifts',
            subtitle: 'Receive gifts from callers',
            value: _allowGifts,
            onChanged: (v) => setState(() => _allowGifts = v),
          ),
          _SettingsTile(
            icon: Icons.block_rounded,
            label: 'Blocked Users',
            subtitle: 'Manage blocked accounts',
            onTap: () => _showBlockedUsers(context),
          ),

          // ── Security ──────────────────────────────────────────────────
          _SectionHeader(title: 'Security'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Logout from All Devices',
            subtitle: 'Sign out everywhere',
            iconColor: AppColors.warning,
            onTap: () => _confirmLogoutAll(context),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: 'Delete Account',
            subtitle: 'Permanently delete your data',
            iconColor: AppColors.callRed,
            labelColor: AppColors.callRed,
            onTap: () => _confirmDeleteAccount(context),
          ),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            subtitle: 'v1.0.0 (Build 1)',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.description_rounded,
            label: 'Terms of Service',
            onTap: () => launchUrl(
              Uri.parse('https://socialcallbackend.replit.app/terms'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            label: 'Privacy Policy',
            onTap: () => launchUrl(
              Uri.parse('https://socialcallbackend.replit.app/privacy'),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showEditNameDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: ref.read(authProvider).user?.name ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Name', style: AppTextStyles.headingMedium),
        content: TextField(
          controller: ctrl,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: AppTextStyles.bodyMedium,
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await ApiClient.dio.patch(
                  ApiEndpoints.profileUpdate,
                  data: {'name': name},
                );
                // Refresh in-memory user state
                await ref.read(authProvider.notifier).refreshBalance();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated!')),
                  );
                }
              } on DioException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiClient.errorMessage(e))),
                  );
                }
              }
            },
            child: Text('Save',
                style:
                    AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final langs = ['English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Bengali'];
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
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Language', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          ...langs.map((l) => ListTile(
            title: Text(l, style: AppTextStyles.bodyLarge),
            trailing: l == 'English'
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: () => Navigator.pop(context),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showQualityPicker(BuildContext context) {
    final options = [
      ('Auto', 'Best based on your network'),
      ('HD', 'High quality, uses more data'),
      ('Standard', 'Balanced quality & data'),
      ('Low', 'Save data, lower quality'),
    ];
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
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Call Quality', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          ...options.map((o) => ListTile(
            title: Text(o.$1, style: AppTextStyles.bodyLarge),
            subtitle: Text(o.$2, style: AppTextStyles.bodySmall),
            trailing: o.$1 == _callQuality
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: () {
              setState(() => _callQuality = o.$1);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Blocked Users', style: AppTextStyles.headingMedium),
        content: Text('You haven\'t blocked anyone yet.',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style:
                    AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmLogoutAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout All Devices', style: AppTextStyles.headingMedium),
        content: Text(
            'This will sign you out from all devices. Continue?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: Text('Logout',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account', style: AppTextStyles.headingMedium),
        content: Text(
            'All your data including wallet balance will be permanently deleted. This cannot be undone.',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiClient.dio.delete(ApiEndpoints.deleteAccount);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              } on DioException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiClient.errorMessage(e))),
                  );
                }
              }
            },
            child: Text('Delete',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.callRed)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: iconColor ?? AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: AppTextStyles.labelLarge.copyWith(
                              color: labelColor ?? AppColors.textPrimary)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTextStyles.bodySmall),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint, size: 20)
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.labelLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withOpacity(0.3),
                inactiveThumbColor: AppColors.textHint,
                inactiveTrackColor: AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: AppTextStyles.caption.copyWith(
              color: color, fontWeight: FontWeight.w700)),
    );
  }
}
