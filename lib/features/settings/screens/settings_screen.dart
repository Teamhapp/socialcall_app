import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Language
  String _language = 'English';

  static const _langs = ['English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Bengali'];
  static const _qualities = [
    ('Auto', 'Best based on your network'),
    ('HD', 'High quality, uses more data'),
    ('Standard', 'Balanced quality & data'),
    ('Low', 'Save data, lower quality'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _callNotifications    = p.getBool('pref_call_notif')    ?? true;
      _messageNotifications = p.getBool('pref_msg_notif')     ?? true;
      _giftNotifications    = p.getBool('pref_gift_notif')    ?? true;
      _promoNotifications   = p.getBool('pref_promo_notif')   ?? false;
      _autoAnswer           = p.getBool('pref_auto_answer')   ?? false;
      _showCallTimer        = p.getBool('pref_call_timer')    ?? true;
      _lowBalanceAlert      = p.getBool('pref_low_balance')   ?? true;
      _showOnlineStatus     = p.getBool('pref_online_status') ?? true;
      _allowGifts           = p.getBool('pref_allow_gifts')   ?? true;
      _callQuality          = p.getString('pref_quality')     ?? 'Auto';
      _language             = p.getString('pref_language')    ?? 'English';
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final p = await SharedPreferences.getInstance();
    if (value is bool)   await p.setBool(key, value);
    if (value is String) await p.setString(key, value);
  }

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
            subtitle: _language,
            onTap: () => _showLanguagePicker(context),
          ),

          // ── Notifications ─────────────────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          _ToggleTile(
            icon: Icons.call_rounded,
            label: 'Incoming Calls',
            subtitle: 'Alert when someone calls you',
            value: _callNotifications,
            onChanged: (v) { setState(() => _callNotifications = v); _savePref('pref_call_notif', v); },
          ),
          _ToggleTile(
            icon: Icons.chat_bubble_rounded,
            label: 'Messages',
            subtitle: 'New message notifications',
            value: _messageNotifications,
            onChanged: (v) { setState(() => _messageNotifications = v); _savePref('pref_msg_notif', v); },
          ),
          _ToggleTile(
            icon: Icons.card_giftcard_rounded,
            label: 'Gifts',
            subtitle: 'When someone sends you a gift',
            value: _giftNotifications,
            onChanged: (v) { setState(() => _giftNotifications = v); _savePref('pref_gift_notif', v); },
          ),
          _ToggleTile(
            icon: Icons.local_offer_rounded,
            label: 'Offers & Promotions',
            subtitle: 'Wallet recharge offers',
            value: _promoNotifications,
            onChanged: (v) { setState(() => _promoNotifications = v); _savePref('pref_promo_notif', v); },
          ),

          // ── Call Preferences ──────────────────────────────────────────
          _SectionHeader(title: 'Call Preferences'),
          _ToggleTile(
            icon: Icons.phone_callback_rounded,
            label: 'Auto-Answer Calls',
            subtitle: 'Automatically accept incoming calls',
            value: _autoAnswer,
            onChanged: (v) { setState(() => _autoAnswer = v); _savePref('pref_auto_answer', v); },
          ),
          _ToggleTile(
            icon: Icons.timer_rounded,
            label: 'Show Call Timer',
            subtitle: 'Display duration during calls',
            value: _showCallTimer,
            onChanged: (v) { setState(() => _showCallTimer = v); _savePref('pref_call_timer', v); },
          ),
          _ToggleTile(
            icon: Icons.warning_amber_rounded,
            label: 'Low Balance Alert',
            subtitle: 'Warn when balance < 1 minute',
            value: _lowBalanceAlert,
            onChanged: (v) { setState(() => _lowBalanceAlert = v); _savePref('pref_low_balance', v); },
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
            onChanged: (v) { setState(() => _showOnlineStatus = v); _savePref('pref_online_status', v); },
          ),
          _ToggleTile(
            icon: Icons.card_giftcard_rounded,
            label: 'Allow Gifts',
            subtitle: 'Receive gifts from callers',
            value: _allowGifts,
            onChanged: (v) { setState(() => _allowGifts = v); _savePref('pref_allow_gifts', v); },
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
              // Capture messenger before async gap to avoid
              // use_build_context_synchronously lint.
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.dio.patch(
                  ApiEndpoints.profileUpdate,
                  data: {'name': name},
                );
                // Refresh in-memory user state
                await ref.read(authProvider.notifier).refreshBalance();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Name updated!')),
                  );
                }
              } on DioException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Select Language', style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            ..._langs.map((l) => ListTile(
              title: Text(l, style: AppTextStyles.bodyLarge),
              trailing: l == _language
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _language = l);
                _savePref('pref_language', l);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showQualityPicker(BuildContext context) {
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
          ..._qualities.map((o) => ListTile(
            title: Text(o.$1, style: AppTextStyles.bodyLarge),
            subtitle: Text(o.$2, style: AppTextStyles.bodySmall),
            trailing: o.$1 == _callQuality
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: () {
              setState(() => _callQuality = o.$1);
              _savePref('pref_quality', o.$1);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Blocked Users', style: AppTextStyles.headingMedium),
            const SizedBox(height: 32),
            Icon(Icons.block_rounded, size: 48, color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No blocked users', style: AppTextStyles.bodyLarge),
            const SizedBox(height: 6),
            Text(
              'Users you block won\'t be able to call or message you.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
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
              // Capture router/messenger before async gap.
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.dio.delete(ApiEndpoints.deleteAccount);
                await ref.read(authProvider.notifier).logout();
                if (mounted) router.go('/login');
              } on DioException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
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
