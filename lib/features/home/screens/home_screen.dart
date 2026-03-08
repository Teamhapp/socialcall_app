import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/hosts_provider.dart';
import '../../../models/host_model.dart';
import '../widgets/host_card.dart';
import '../widgets/category_chip.dart';
import '../../wallet/screens/wallet_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  final _searchController = TextEditingController();
  final _categories = ['All', 'Online', 'Hindi', 'English', 'Tamil', 'Telugu'];
  MessageCallback? _incomingCallCb;

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    _incomingCallCb = (data) {
      if (!mounted) return;
      final callId = data['callId'] as String? ?? '';
      final callType = data['callType'] as String? ?? 'audio';
      final caller = data['caller'] as Map<String, dynamic>? ?? {};
      final callerName = caller['name'] as String? ?? 'Someone';
      final callerAvatar = caller['avatar'] as String?;

      _showIncomingCallDialog(
        callId: callId,
        isVideo: callType == 'video',
        callerName: callerName,
        callerAvatar: callerAvatar,
      );
    };
    SocketService.on('incoming_call', _incomingCallCb!);
  }

  void _showIncomingCallDialog({
    required String callId,
    required bool isVideo,
    required String callerName,
    String? callerAvatar,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomingCallDialog(
        callId: callId,
        isVideo: isVideo,
        callerName: callerName,
        callerAvatar: callerAvatar,
        onAccept: () async {
          Navigator.pop(context);
          try {
            final resp = await ApiClient.dio
                .post(ApiEndpoints.callAccept(callId));
            final data = ApiClient.parseData(resp) as Map<String, dynamic>;
            final host = HostModel.fromJson(
              data['host'] as Map<String, dynamic>,
            );
            if (mounted) {
              context.go('/call', extra: {
                'host': host,
                'isVideo': isVideo,
                'callId': callId,
                'isCaller': false,
              });
            }
          } on DioException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ApiClient.errorMessage(e))),
              );
            }
          }
        },
        onDecline: () {
          Navigator.pop(context);
          SocketService.emit('call_declined', {'callId': callId});
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_incomingCallCb != null) {
      SocketService.off('incoming_call', _incomingCallCb);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostsState = ref.watch(hostsProvider);
    final hostsNotifier = ref.read(hostsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _DiscoveryTab(
            categories: _categories,
            selectedCategory: hostsState.filter,
            searchController: _searchController,
            filteredHosts: hostsState.hosts,
            isLoading: hostsState.isLoading,
            onCategoryChanged: hostsNotifier.setFilter,
            onSearchChanged: hostsNotifier.setSearch,
            onRefresh: () => hostsNotifier.fetchHosts(),
          ),
          const _ChatListTab(),
          const WalletScreen(isEmbedded: true),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryTab extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchController;
  final List<HostModel> filteredHosts;
  final bool isLoading;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;

  const _DiscoveryTab({
    required this.categories,
    required this.selectedCategory,
    required this.searchController,
    required this.filteredHosts,
    required this.isLoading,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good Evening! 👋',
                              style: AppTextStyles.bodyMedium),
                          Text('Find your host',
                              style: AppTextStyles.headingLarge),
                        ],
                      ),
                      const Spacer(),
                      // Wallet balance chip
                      GestureDetector(
                        onTap: () => context.go('/wallet'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 16),
                              const SizedBox(width: 4),
                              Consumer(
                                builder: (_, ref, __) {
                                  final user = ref.watch(authProvider).user;
                                  return Text(
                                    'Rs.${user?.walletBalance.toStringAsFixed(0) ?? '0'}',
                                    style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textHint),
                      suffixIcon: searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.textHint),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categories
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => CategoryChip(
                        label: categories[i],
                        isSelected: selectedCategory == categories[i],
                        onTap: () => onCategoryChanged(categories[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Online hosts count
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredHosts.where((h) => h.isOnline).length} hosts online now',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.online),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Host grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: filteredHosts.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text('No hosts found',
                                style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => HostCard(host: filteredHosts[i]),
                      childCount: filteredHosts.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
      ),
    );
  }
}

class _ChatListTab extends StatelessWidget {
  const _ChatListTab();

  @override
  Widget build(BuildContext context) {
    final hosts = HostModel.demoHosts.take(3).toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('Messages', style: AppTextStyles.headingLarge),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: hosts.length,
              itemBuilder: (_, i) {
                final host = hosts[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(host.avatar ?? ''),
                      ),
                      if (host.isOnline)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.online,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.background, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(host.name, style: AppTextStyles.labelLarge),
                  subtitle: Text('Tap to start chatting',
                      style: AppTextStyles.bodySmall),
                  trailing: Text('2h ago', style: AppTextStyles.caption),
                  onTap: () =>
                      context.go('/chat/${host.id}', extra: host),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.avatar != null
                      ? NetworkImage(user!.avatar!) as ImageProvider
                      : null,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: user?.avatar == null
                      ? const Icon(Icons.person_rounded,
                          size: 50, color: AppColors.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? 'User', style: AppTextStyles.headingMedium),
            Text(user?.phone ?? '', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            ..._profileMenuItems(context, ref).map((item) => Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: AppColors.card,
                  leading: Icon(item.icon,
                      color: item.isDestructive ? Colors.redAccent : AppColors.primary),
                  title: Text(item.label,
                      style: AppTextStyles.bodyLarge.copyWith(
                          color: item.isDestructive ? Colors.redAccent : null)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint),
                  onTap: item.onTap,
                ),
                const SizedBox(height: 8),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

// ── Profile menu helpers ──────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.onTap,
  });
}

List<_MenuItem> _profileMenuItems(BuildContext context, WidgetRef ref) => [
  _MenuItem(
    icon: Icons.history_rounded,
    label: 'Call History',
    onTap: () {}, // TODO: /call-history
  ),
  _MenuItem(
    icon: Icons.favorite_rounded,
    label: 'Following',
    onTap: () {}, // TODO: /following
  ),
  _MenuItem(
    icon: Icons.support_agent_rounded,
    label: 'Support',
    onTap: () => context.go('/help'),
  ),
  _MenuItem(
    icon: Icons.settings_rounded,
    label: 'Settings',
    onTap: () => context.go('/settings'),
  ),
  _MenuItem(
    icon: Icons.logout_rounded,
    label: 'Logout',
    isDestructive: true,
    onTap: () async {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    },
  ),
];

// ── Incoming Call Dialog ──────────────────────────────────────────────────────

class _IncomingCallDialog extends StatelessWidget {
  final String callId;
  final bool isVideo;
  final String callerName;
  final String? callerAvatar;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallDialog({
    required this.callId,
    required this.isVideo,
    required this.callerName,
    this.callerAvatar,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing ring around avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: callerAvatar != null
                    ? NetworkImage(callerAvatar!)
                    : null,
                backgroundColor: AppColors.card,
                child: callerAvatar == null
                    ? const Icon(Icons.person_rounded,
                        size: 44, color: AppColors.textHint)
                    : null,
              ),
            ),

            const SizedBox(height: 16),

            Text('Incoming Call', style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.2,
            )),
            const SizedBox(height: 6),
            Text(callerName, style: AppTextStyles.headingLarge),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  isVideo ? 'Video Call' : 'Audio Call',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline
                Column(
                  children: [
                    GestureDetector(
                      onTap: onDecline,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.callRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.callRed.withOpacity(0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call_end_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Decline', style: AppTextStyles.caption),
                  ],
                ),

                // Accept
                Column(
                  children: [
                    GestureDetector(
                      onTap: onAccept,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.callGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.callGreen.withOpacity(0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Accept', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
