import 'dart:ui';
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
import '../../live/screens/watch_stream_screen.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../offers/models/offer_model.dart';
import '../../offers/providers/offers_provider.dart';

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
              currentUserId: ref.read(authProvider).user?.id,
            ),
            _ChatListTab(
            onUnreadCountChanged: (n) =>
                setState(() => _unreadCount = n),
          ),
            const WalletScreen(isEmbedded: true),
            const _ProfileTab(),
          ],
        ),
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: _navIndex,
          unreadCount: _unreadCount,
          onTap: _goToTab,
        ),
      ),
    );
  }
}

// ── Floating glassmorphic bottom navigation ────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  static const _items = [
    (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Wallet'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final selected = i == currentIndex;
                  final (outlineIcon, filledIcon, label) = _items[i];
                  final icon = Icon(
                    selected ? filledIcon : outlineIcon,
                    color: selected ? AppColors.primary : AppColors.textHint,
                    size: 22,
                  );
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: selected
                                ? BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                : null,
                            child: i == 1 && unreadCount > 0
                                ? Badge.count(
                                    count: unreadCount,
                                    child: icon,
                                  )
                                : icon,
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                            child: Text(label),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Discovery tab ─────────────────────────────────────────────────────────────

class _DiscoveryTab extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchController;
  final List<HostModel> filteredHosts;
  final bool isLoading;
  final String? userName;
  final String? currentUserId;
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
    this.currentUserId,
  });

  @override
  State<_DiscoveryTab> createState() => _DiscoveryTabState();
}

class _DiscoveryTabState extends State<_DiscoveryTab> {
  bool _randomCallLoading = false;
  bool _randomVideoMode   = false;

  // ── Random Call ─────────────────────────────────────────────────────────────
  Future<void> _startRandomCall({String? gender, bool isVideo = false}) async {
    if (_randomCallLoading) return;
    HapticFeedback.mediumImpact();
    setState(() => _randomCallLoading = true);
    try {
      // Respect active language filter if one is set
      final lang = (widget.selectedCategory != 'All' &&
              widget.selectedCategory != 'Online')
          ? widget.selectedCategory
          : null;
      final qp = <String, dynamic>{};
      if (lang != null)    qp['language'] = lang;
      if (gender != null)  qp['gender']   = gender;

      final hostResp = await ApiClient.dio.get(
        ApiEndpoints.randomHost,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final hostData =
          ApiClient.parseData(hostResp) as Map<String, dynamic>;
      final host = HostModel.fromJson(hostData);

      final callResp = await ApiClient.dio.post(
        ApiEndpoints.callInitiate,
        data: {'hostId': host.id, 'callType': isVideo ? 'video' : 'audio'},
      );
      final callData =
          ApiClient.parseData(callResp) as Map<String, dynamic>;
      final callId = callData['callId']?.toString() ?? '';
      if (callId.isEmpty) throw Exception('No callId returned');

      if (!mounted) return;
      context.push('/call', extra: {
        'host': host,
        'isVideo': isVideo,
        'callId': callId,
        'isCaller': true,
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = ApiClient.errorMessage(e);
      AppSnackBar.error(context,
          msg.contains('404') ? 'No online hosts right now. Try again soon!' : msg);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No online hosts available right now.');
    } finally {
      if (mounted) setState(() => _randomCallLoading = false);
    }
  }

  // ── Combined filter sheet (Language + Gender + Age Group) ───────────────────
  void _showFilterSheet(BuildContext context, HostsNotifier hostsNotifier, HostsState hostsState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        selectedLanguage: widget.selectedCategory,
        selectedGender: hostsState.genderFilter,
        selectedAgeGroup: hostsState.ageGroupFilter,
        onApply: (lang, gender, ageGroup) {
          widget.onCategoryChanged(lang);
          hostsNotifier.setGenderFilter(gender);
          hostsNotifier.setAgeGroupFilter(ageGroup);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
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
                            Text('Hi, ${_firstName(widget.userName)}!',
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

                    // ── Search bar + filter button ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widget.searchController,
                            onChanged: widget.onSearchChanged,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppColors.textHint),
                              suffixIcon:
                                  widget.searchController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            widget.searchController.clear();
                                            widget.onSearchChanged('');
                                          },
                                          child: const Icon(
                                              Icons.close_rounded,
                                              color: AppColors.textHint),
                                        )
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filter button (Language + Gender + Age)
                        Consumer(
                          builder: (ctx, ref, _) {
                            final hs = ref.watch(hostsProvider);
                            final hn = ref.read(hostsProvider.notifier);
                            final isActive = (widget.selectedCategory != 'All' &&
                                    widget.selectedCategory != 'Online') ||
                                hs.genderFilter != null ||
                                hs.ageGroupFilter != null;
                            return GestureDetector(
                              onTap: () => _showFilterSheet(ctx, hn, hs),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? AppColors.primaryGradient
                                      : null,
                                  color: isActive ? null : AppColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.transparent
                                        : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textHint,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Category chips (Online + quick langs) ──────────────
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => CategoryChip(
                          label: widget.categories[i],
                          isSelected:
                              widget.selectedCategory == widget.categories[i],
                          onTap: () =>
                              widget.onCategoryChanged(widget.categories[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Tag filter chips ───────────────────────────────────
                    Consumer(
                      builder: (ctx, ref, _) {
                        final tagsAsync = ref.watch(tagsProvider);
                        final hostsState = ref.watch(hostsProvider);
                        return tagsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (tags) {
                            if (tags.isEmpty) return const SizedBox.shrink();
                            return SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: tags.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final tag = tags[i];
                                  final isActive = hostsState.tagFilter == tag;
                                  return GestureDetector(
                                    onTap: () => ref
                                        .read(hostsProvider.notifier)
                                        .setTagFilter(isActive ? null : tag),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.primary
                                            : AppColors.card,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isActive
                                              ? AppColors.primary
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: AppTextStyles.caption.copyWith(
                                          color: isActive
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── 🎲 Random Call banner ─────────────────────────────
                    _RandomCallBanner(
                      isLoading: _randomCallLoading,
                      isVideoMode: _randomVideoMode,
                      onVideoToggled: (v) =>
                          setState(() => _randomVideoMode = v),
                      onAnyGender: () =>
                          _startRandomCall(isVideo: _randomVideoMode),
                      onMaleHost: () => _startRandomCall(
                          gender: 'male', isVideo: _randomVideoMode),
                      onFemaleHost: () => _startRandomCall(
                          gender: 'female', isVideo: _randomVideoMode),
                      activeLanguage:
                          (widget.selectedCategory != 'All' &&
                                  widget.selectedCategory != 'Online')
                              ? widget.selectedCategory
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── LIVE NOW strip ─────────────────────────────────────
                    _LiveNowStrip(),
                    const SizedBox(height: 8),

                    // ── Deals / Offers strip ────────────────────────────────
                    _DealsStrip(),
                    const SizedBox(height: 8),

                    // ── Online hosts count ─────────────────────────────────
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
                          '${widget.filteredHosts.where((h) => h.isOnline).length} hosts online now',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.online),
                        ),
                        const Spacer(),
                        // Active language filter badge
                        if (widget.selectedCategory != 'All' &&
                            widget.selectedCategory != 'Online')
                          GestureDetector(
                            onTap: () =>
                                widget.onCategoryChanged('All'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.selectedCategory,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.close_rounded,
                                      color: AppColors.primary, size: 12),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Host grid ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: widget.filteredHosts.isEmpty
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
                              if (widget.selectedCategory != 'All') ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () =>
                                      widget.onCategoryChanged('All'),
                                  child: Text(
                                    'Clear filter',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(
                                            color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => HostCard(
                          host: widget.filteredHosts[i],
                          currentUserId: widget.currentUserId,
                        ),
                        childCount: widget.filteredHosts.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.67,
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

// ── Random Call Banner ────────────────────────────────────────────────────────

class _RandomCallBanner extends StatelessWidget {
  final bool isLoading;
  final bool isVideoMode;
  final ValueChanged<bool> onVideoToggled;
  final VoidCallback onAnyGender;
  final VoidCallback onMaleHost;
  final VoidCallback onFemaleHost;
  final String? activeLanguage;

  const _RandomCallBanner({
    required this.isLoading,
    required this.isVideoMode,
    required this.onVideoToggled,
    required this.onAnyGender,
    required this.onMaleHost,
    required this.onFemaleHost,
    this.activeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.40),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              height: 64,
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: title + audio/video toggle
                Row(
                  children: [
                    const Text('🎲', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      activeLanguage != null
                          ? 'Random $activeLanguage Call'
                          : 'Random Call',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    // Audio / Video toggle pill
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TogglePill(
                            label: '🎙 Audio',
                            selected: !isVideoMode,
                            onTap: () => onVideoToggled(false),
                          ),
                          _TogglePill(
                            label: '📹 Video',
                            selected: isVideoMode,
                            onTap: () => onVideoToggled(true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom row: gender call buttons
                Row(
                  children: [
                    _GenderCallBtn(
                        emoji: '🎲', label: 'Any', onTap: onAnyGender),
                    const SizedBox(width: 8),
                    _GenderCallBtn(
                        emoji: '👨', label: 'Male', onTap: onMaleHost),
                    const SizedBox(width: 8),
                    _GenderCallBtn(
                        emoji: '👩', label: 'Female', onTap: onFemaleHost),
                  ],
                ),
              ],
            ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TogglePill(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color:
                selected ? const Color(0xFF7C3AED) : Colors.white,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GenderCallBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _GenderCallBtn(
      {required this.emoji,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Combined filter bottom sheet (Language + Gender + Age Group) ──────────────

class _FilterSheet extends StatefulWidget {
  final String selectedLanguage;
  final String? selectedGender;
  final String? selectedAgeGroup;
  final void Function(String lang, String? gender, String? ageGroup) onApply;

  const _FilterSheet({
    required this.selectedLanguage,
    required this.selectedGender,
    required this.selectedAgeGroup,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _language;
  String? _gender;
  String? _ageGroup;

  static const _languages = [
    'Hindi', 'English', 'Tamil', 'Telugu', 'Kannada',
    'Bengali', 'Marathi', 'Malayalam', 'Punjabi', 'Gujarati',
    'Odia', 'Urdu', 'Assamese', 'Bhojpuri',
  ];

  @override
  void initState() {
    super.initState();
    _language = widget.selectedLanguage;
    _gender   = widget.selectedGender;
    _ageGroup = widget.selectedAgeGroup;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── Language section ───────────────────────────────────────────
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.language_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Text('Language', style: AppTextStyles.headingMedium),
                const Spacer(),
                if (_language != 'All')
                  GestureDetector(
                    onTap: () => setState(() => _language = 'All'),
                    child: Text('Clear',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // "All" option
            _LangChip(
              label: 'All Languages',
              selected: _language == 'All',
              onTap: () => setState(() => _language = 'All'),
            ),
            const SizedBox(height: 10),

            // Language grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages
                  .map((l) => _LangChip(
                        label: l,
                        selected: _language == l,
                        onTap: () => setState(() => _language = l),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── Gender section ─────────────────────────────────────────────
            Row(
              children: [
                const Text('👤', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('Gender', style: AppTextStyles.headingMedium),
                const Spacer(),
                if (_gender != null)
                  GestureDetector(
                    onTap: () => setState(() => _gender = null),
                    child: Text('Clear',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterOptionTile(
                    label: 'Any',
                    emoji: '🌐',
                    selected: _gender == null,
                    onTap: () => setState(() => _gender = null)),
                const SizedBox(width: 8),
                _FilterOptionTile(
                    label: 'Male',
                    emoji: '👨',
                    selected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male')),
                const SizedBox(width: 8),
                _FilterOptionTile(
                    label: 'Female',
                    emoji: '👩',
                    selected: _gender == 'female',
                    onTap: () => setState(() => _gender = 'female')),
              ],
            ),
            const SizedBox(height: 20),

            // ── Age group section ──────────────────────────────────────────
            Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('Age Group', style: AppTextStyles.headingMedium),
                const Spacer(),
                if (_ageGroup != null)
                  GestureDetector(
                    onTap: () => setState(() => _ageGroup = null),
                    child: Text('Clear',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterOptionTile(
                    label: 'Any',
                    emoji: '∞',
                    selected: _ageGroup == null,
                    onTap: () => setState(() => _ageGroup = null)),
                const SizedBox(width: 8),
                _FilterOptionTile(
                    label: '18-25',
                    emoji: '🧑',
                    selected: _ageGroup == '18-25',
                    onTap: () => setState(() => _ageGroup = '18-25')),
                const SizedBox(width: 8),
                _FilterOptionTile(
                    label: '25-35',
                    emoji: '👔',
                    selected: _ageGroup == '25-35',
                    onTap: () => setState(() => _ageGroup = '25-35')),
                const SizedBox(width: 8),
                _FilterOptionTile(
                    label: '35+',
                    emoji: '🧓',
                    selected: _ageGroup == '35+',
                    onTap: () => setState(() => _ageGroup = '35+')),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            GradientButton(
              label: 'Apply Filters',
              height: 50,
              icon: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 18),
              onTap: () {
                widget.onApply(_language, _gender, _ageGroup);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Deals / Offers strip ───────────────────────────────────────────────────────

class _DealsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);
    return offersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: offers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) => _OfferCard(offer: offers[i]),
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final OfferModel offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [offer.bgColor, offer.bgColor.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(offer.iconEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (offer.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    offer.subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (offer.promoCode != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offer.promoCode!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── LIVE NOW strip ─────────────────────────────────────────────────────────────

class _LiveNowStrip extends StatefulWidget {
  @override
  State<_LiveNowStrip> createState() => _LiveNowStripState();
}

class _LiveNowStripState extends State<_LiveNowStrip> {
  List<Map<String, dynamic>> _streams = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.dio.get(ApiEndpoints.streams);
      final list = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      if (mounted) setState(() { _streams = list; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _streams.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.callRed, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('LIVE NOW', style: AppTextStyles.labelMedium.copyWith(color: AppColors.callRed)),
            const SizedBox(width: 4),
            Text('${_streams.length}', style: AppTextStyles.caption.copyWith(
                color: AppColors.callRed, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _streams.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = _streams[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WatchStreamScreen(
                    streamId: s['id'].toString(),
                    hostName: s['host_name'] as String? ?? 'Host',
                    title: s['title'] as String? ?? 'Live Stream',
                  ),
                )),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.callRed.withValues(alpha: 0.6), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (s['host_avatar'] != null)
                          Image.network(s['host_avatar'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: AppColors.card))
                        else
                          const ColoredBox(color: AppColors.card,
                              child: Icon(Icons.person_rounded,
                                  color: AppColors.textHint, size: 32)),
                        // Gradient overlay
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        // LIVE badge + viewer count
                        Positioned(
                          top: 6, left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.callRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LIVE',
                                style: TextStyle(color: Colors.white, fontSize: 8,
                                    fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                          ),
                        ),
                        Positioned(
                          bottom: 6, left: 0, right: 0,
                          child: Column(
                            children: [
                              Text(s['host_name'] as String? ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.remove_red_eye_rounded,
                                      color: Colors.white70, size: 10),
                                  const SizedBox(width: 2),
                                  Text('${s['viewer_count'] ?? 0}',
                                      style: const TextStyle(color: Colors.white70,
                                          fontSize: 9, fontFamily: 'Poppins')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
                    // needs:
                    //   id       = hosts-table UUID (for calls & gifts)
                    //   userId   = users-table UUID (for messages & socket)
                    final hostId =
                        conv['host_id'] as String? ?? '';
                    final audioRate =
                        double.tryParse('${conv['audio_rate_per_min'] ?? 0}') ??
                            0.0;
                    final videoRate =
                        double.tryParse('${conv['video_rate_per_min'] ?? 0}') ??
                            0.0;
                    final fakeHost = HostModel(
                      id: hostId,
                      userId: otherUserId,
                      name: otherName,
                      avatar: otherAvatar,
                      bio: '',
                      languages: const [],
                      audioRatePerMin: audioRate,
                      videoRatePerMin: videoRate,
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
        AppSnackBar.error(context, ApiClient.errorMessage(e));
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
            // ── Avatar with gradient ring ────────────────────────────
            GestureDetector(
              onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
              child: Stack(
                children: [
                  // Gradient ring
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: user?.avatar != null
                          ? NetworkImage(user!.avatar!) as ImageProvider
                          : null,
                      backgroundColor:
                          AppColors.card,
                      child: user?.avatar == null
                          ? const Icon(Icons.person_rounded,
                              size: 50, color: AppColors.primary)
                          : null,
                    ),
                  ),
                  if (_uploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.background, width: 2),
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
            Text(user?.phone ?? '',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint)),
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
