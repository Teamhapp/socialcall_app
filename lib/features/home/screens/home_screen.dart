import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
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

// ── Time-based greeting ───────────────────────────────────────────────────────
String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 5)  return 'Good Night! 🌙';
  if (h < 12) return 'Good Morning! ☀️';
  if (h < 17) return 'Good Afternoon! 🌤️';
  if (h < 21) return 'Good Evening! 🌆';
  return 'Good Night! 🌙';
}

String _firstName(String? name) {
  if (name == null || name.trim().isEmpty) return 'there';
  return name.trim().split(' ').first;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  int _unreadCount = 0;
  late final PageController _pageController;
  final _searchController = TextEditingController();
  final _categories = ['All', 'Online', 'Hindi', 'English', 'Tamil', 'Telugu'];
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _navIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToTab(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostsState = ref.watch(hostsProvider);
    final hostsNotifier = ref.read(hostsProvider.notifier);

    // Show snackbar when a followed host comes online
    ref.listen<HostsState>(hostsProvider, (prev, next) {
      final msg = next.followedHostOnlineMessage;
      if (msg != null && msg != prev?.followedHostOnlineMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                _goToTab(0);
                hostsNotifier.setFilter('Online');
              },
            ),
          ),
        );
        hostsNotifier.clearFollowedHostOnlineMessage();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on the Discover tab, go back to it first.
        if (_navIndex != 0) {
          _pageController.jumpToPage(0);
          setState(() => _navIndex = 0);
          return;
        }
        // Double-tap to exit.
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        // ── PageView replaces IndexedStack — enables swipe-between-tabs ──
        body: PageView(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (i) => setState(() => _navIndex = i),
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
              userName: ref.read(authProvider).user?.name,
            ),
            _ChatListTab(
            onUnreadCountChanged: (n) =>
                setState(() => _unreadCount = n),
          ),
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
            onTap: _goToTab,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore_rounded),
                label: 'Discover',
              ),
              BottomNavigationBarItem(
                icon: Badge.count(
                  count: _unreadCount,
                  isLabelVisible: _unreadCount > 0,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                activeIcon: Badge.count(
                  count: _unreadCount,
                  isLabelVisible: _unreadCount > 0,
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                label: 'Chats',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Wallet',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Discovery tab ─────────────────────────────────────────────────────────────

class _DiscoveryTab extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchController;
  final List<HostModel> filteredHosts;
  final bool isLoading;
  final String? userName;
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
    this.userName,
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
                            Text(_timeGreeting(),
                                style: AppTextStyles.bodyMedium),
                            Text('Hi, ${_firstName(userName)}!',
                                style: AppTextStyles.headingLarge),
                          ],
                        ),
                        const Spacer(),
                        // Wallet balance chip
                        GestureDetector(
                          onTap: () => context.push('/wallet'),
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
                                  builder: (_, ref, _) {
                                    final user =
                                        ref.watch(authProvider).user;
                                    return Text(
                                      'Rs.${user?.walletBalance.toStringAsFixed(0) ?? '0'}',
                                      style: AppTextStyles.labelLarge
                                          .copyWith(color: Colors.white),
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
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
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
                          width: 8,
                          height: 8,
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

// ── Chat list tab ─────────────────────────────────────────────────────────────

class _ChatListTab extends StatefulWidget {
  final void Function(int unreadCount)? onUnreadCountChanged;
  const _ChatListTab({this.onUnreadCountChanged});

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.conversations);
      final raw = ApiClient.parseData(resp) as List? ?? [];
      if (mounted) {
        final convs = raw.cast<Map<String, dynamic>>();
        final total = convs.fold<int>(
          0,
          (sum, c) => sum + (int.tryParse('${c['unread_count'] ?? 0}') ?? 0),
        );
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
        widget.onUnreadCountChanged?.call(total);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Swipe background helper ───────────────────────────────────────────────
  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required Alignment alignment,
    required EdgeInsets padding,
  }) =>
      Container(
        alignment: alignment,
        padding: padding,
        color: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('Messages', style: AppTextStyles.headingLarge),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_conversations.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 52, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text('No conversations yet',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Call a host to unlock chat!',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (_, i) {
                    final conv = _conversations[i];
                    final otherUserId =
                        conv['other_user_id'] as String? ?? '';
                    final otherName =
                        conv['other_name'] as String? ?? 'Unknown';
                    final otherAvatar = conv['other_avatar'] as String?;
                    final lastMsg =
                        conv['last_message'] as String? ?? '';
                    final isOnline =
                        conv['is_online'] as bool? ?? false;
                    final unread =
                        int.tryParse('${conv['unread_count'] ?? 0}') ??
                            0;
                    final lastAt = conv['last_message_at'] != null
                        ? DateTime.tryParse(
                            conv['last_message_at'] as String)
                        : null;

                    // Build a minimal HostModel so ChatScreen gets what it
                    // needs (id = other_user_id for socket communication)
                    final fakeHost = HostModel(
                      id: otherUserId,
                      userId: otherUserId,
                      name: otherName,
                      avatar: otherAvatar,
                      bio: '',
                      languages: const [],
                      audioRatePerMin: 0,
                      videoRatePerMin: 0,
                      rating: 0,
                      totalCalls: 0,
                      isOnline: isOnline,
                      isVerified: false,
                      followersCount: 0,
                    );

                    final tile = ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage: otherAvatar != null
                                ? NetworkImage(otherAvatar)
                                : null,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: otherAvatar == null
                                ? const Icon(Icons.person_rounded,
                                    color: AppColors.primary)
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.online,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.background,
                                      width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(otherName,
                                style: AppTextStyles.labelLarge),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        lastMsg.isNotEmpty ? lastMsg : 'Tap to chat',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: lastAt != null
                          ? Text(
                              _formatTime(lastAt),
                              style: AppTextStyles.caption,
                            )
                          : null,
                      onTap: () => context.push(
                          '/chat/$otherUserId',
                          extra: fakeHost),
                    );

                    // ── Bidirectional swipe ──────────────────────────────
                    // Swipe right (startToEnd) → mark as read (clear badge)
                    // Swipe left  (endToStart) → delete conversation
                    return Dismissible(
                      key: Key('conv_$otherUserId'),
                      background: _swipeBg(
                        color: Colors.blueAccent,
                        icon: Icons.mark_chat_read_rounded,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                      ),
                      secondaryBackground: _swipeBg(
                        color: AppColors.callRed,
                        icon: Icons.delete_outline_rounded,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                      ),
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          // Mark as read locally — don't remove item
                          setState(() =>
                              _conversations[i]['unread_count'] = 0);
                          return false;
                        }
                        return true; // allow delete
                      },
                      onDismissed: (_) =>
                          setState(() => _conversations.removeAt(i)),
                      child: tile,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM').format(dt);
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(picked.path,
            filename: 'avatar.jpg'),
      });
      await ApiClient.dio.patch(ApiEndpoints.profileUpdate, data: formData);
      await ref.read(authProvider.notifier).refreshBalance();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Grouped section builder ───────────────────────────────────────────────
  Widget _buildSection(String label, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    shape: isLast
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(14)))
                        : null,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.isDestructive
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : item.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.isDestructive
                            ? Colors.redAccent
                            : item.iconColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: AppTextStyles.bodyLarge.copyWith(
                          color: item.isDestructive
                              ? Colors.redAccent
                              : null),
                    ),
                    subtitle: item.subtitle != null
                        ? Text(item.subtitle!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint))
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint, size: 18),
                    onTap: item.onTap,
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, indent: 54, color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isHost = user?.isHost ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // ── Avatar ──────────────────────────────────────────────────
            GestureDetector(
              onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user?.avatar != null
                        ? NetworkImage(user!.avatar!) as ImageProvider
                        : null,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.2),
                    child: user?.avatar == null
                        ? const Icon(Icons.person_rounded,
                            size: 50, color: AppColors.primary)
                        : null,
                  ),
                  if (_uploadingAvatar)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
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
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? 'User', style: AppTextStyles.headingMedium),
            Text(user?.phone ?? '', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),

            // ── Section 1: Host ──────────────────────────────────────────
            _buildSection('Host', [
              if (isHost)
                _MenuItem(
                  icon: Icons.dashboard_rounded,
                  iconColor: Colors.orange,
                  label: 'Host Dashboard',
                  subtitle: 'Earnings, calls & online status',
                  onTap: () => context.push('/host-dashboard'),
                )
              else
                _MenuItem(
                  icon: Icons.headset_mic_rounded,
                  iconColor: Colors.orange,
                  label: 'Become a Host',
                  subtitle: 'Earn by taking calls',
                  onTap: () => context.push('/become-host'),
                ),
            ]),

            // ── Section 2: Activity ──────────────────────────────────────
            _buildSection('Activity', [
              _MenuItem(
                icon: Icons.history_rounded,
                iconColor: Colors.blueAccent,
                label: 'Call History',
                onTap: () => context.push('/call-history'),
              ),
              _MenuItem(
                icon: Icons.favorite_rounded,
                iconColor: Colors.pinkAccent,
                label: 'Following',
                onTap: () => context.push('/following'),
              ),
            ]),

            // ── Section 3: Account ───────────────────────────────────────
            _buildSection('Account', [
              _MenuItem(
                icon: Icons.support_agent_rounded,
                iconColor: Colors.teal,
                label: 'Support',
                onTap: () => context.push('/help'),
              ),
              _MenuItem(
                icon: Icons.settings_rounded,
                iconColor: Colors.grey,
                label: 'Settings',
                onTap: () => context.push('/settings'),
              ),
            ]),

            // ── Logout (standalone) ──────────────────────────────────────
            _buildSection('', [
              _MenuItem(
                icon: Icons.logout_rounded,
                iconColor: Colors.redAccent,
                label: 'Logout',
                isDestructive: true,
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Menu helpers ──────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.isDestructive = false,
    this.onTap,
  });
}

// Incoming call is now handled globally by IncomingCallOverlay in main.dart.
// No per-screen dialog or socket listener needed here.
