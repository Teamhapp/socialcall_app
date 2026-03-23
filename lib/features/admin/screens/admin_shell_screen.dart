import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/admin_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_hosts_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_more_screen.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.dashboard_rounded,      label: 'Dashboard'),
    (icon: Icons.people_rounded,         label: 'Users'),
    (icon: Icons.headset_mic_rounded,    label: 'Hosts'),
    (icon: Icons.payments_rounded,       label: 'Payouts'),
    (icon: Icons.more_horiz_rounded,     label: 'More'),
  ];

  final _screens = const [
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminHostsScreen(),
    AdminPayoutsScreen(),
    AdminMoreScreen(),
  ];

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Logout', style: AppTextStyles.headingSmall),
        content: Text('Exit admin panel?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.callRed)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(adminProvider.notifier).logout();
      if (mounted) context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Admin Panel', style: AppTextStyles.headingSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.callRed, size: 22),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon, color: AppColors.textHint),
                  selectedIcon: Icon(t.icon, color: AppColors.primary),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
