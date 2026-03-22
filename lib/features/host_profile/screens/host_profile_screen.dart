import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gift_picker_sheet.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/online_badge.dart';
import '../../live/screens/watch_stream_screen.dart';
import '../../report/widgets/report_dialog.dart';

class HostProfileScreen extends ConsumerStatefulWidget {
  final HostModel host;
  const HostProfileScreen({super.key, required this.host});

  @override
  ConsumerState<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends ConsumerState<HostProfileScreen> {
  bool _isStartingCall = false;
  bool _isFollowing = false;
  bool _isTogglingFollow = false;
  bool _isSubscribed = false;
  bool _isSubscribing = false;
  Map<String, dynamic>? _activeStream;

  // Reviews
  List<ReviewModel> _reviews = [];
  int _totalReviews = 0;
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
    _checkSubscription();
    _checkActiveStream();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final resp = await ApiClient.dio.get(
          ApiEndpoints.hostById(widget.host.id));
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final rawReviews = data['recent_reviews'] as List? ?? [];
      final totalRev = data['total_reviews'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _reviews = rawReviews
              .cast<Map<String, dynamic>>()
              .map(ReviewModel.fromJson)
              .toList();
          _totalReviews = totalRev;
          _reviewsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _checkSubscription() async {
    try {
      final res = await ApiClient.dio.get(
          ApiEndpoints.subscriptionStatus(widget.host.id));
      if (mounted) {
        setState(() => _isSubscribed = res.data['data']['isSubscribed'] == true);
      }
    } catch (_) {}
  }

  Future<void> _checkActiveStream() async {
    try {
      final res = await ApiClient.dio.get(ApiEndpoints.streams);
      final streams = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      final hostStream = streams.where(
        (s) => s['host_user_id'].toString() == widget.host.id,
      ).firstOrNull;
      if (mounted) setState(() => _activeStream = hostStream);
    } catch (_) {}
  }

  Future<void> _toggleSubscribe() async {
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);
    HapticFeedback.mediumImpact();
    try {
      if (_isSubscribed) {
        await ApiClient.dio.delete(ApiEndpoints.subscribeHost(widget.host.id));
        if (mounted) setState(() => _isSubscribed = false);
      } else {
        final confirm = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetCtx) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),
                Text('Subscribe to ${widget.host.name}',
                    style: AppTextStyles.headingSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '99 coins/month · Get priority access & exclusive perks',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Subscribe · ₹99',
                  height: 52,
                  icon: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 18),
                  onTap: () => Navigator.pop(sheetCtx, true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  child: Text('Maybe later',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint)),
                ),
              ],
            ),
          ),
        );
        if (confirm != true) return;
        await ApiClient.dio.post(ApiEndpoints.subscribeHost(widget.host.id));
        if (mounted) setState(() => _isSubscribed = true);
        if (mounted) {
          AppSnackBar.success(context, 'Subscribed to ${widget.host.name}! ✓');
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        AppSnackBar.error(context, ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  Future<void> _checkFollowing() async {
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.hostFollowing);
      final list = (ApiClient.parseData(resp) as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _isFollowing = list.any((h) => h['id'] == widget.host.id);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;
    setState(() => _isTogglingFollow = true);
    HapticFeedback.lightImpact();
    try {
      await ApiClient.dio.post(ApiEndpoints.hostFollow(widget.host.id));
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } on DioException catch (e) {
      if (mounted) {
        AppSnackBar.error(context, ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  /// Initiates a call: POSTs to /api/calls/initiate, then navigates to CallScreen.
  Future<void> _startCall(bool isVideo) async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);

    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.callInitiate,
        data: {
          'hostId': widget.host.id,
          'callType': isVideo ? 'video' : 'audio',
        },
      );
      final data = ApiClient.parseData(resp) as Map<String, dynamic>?;
      final callId = data?['callId']?.toString() ?? '';
      if (callId.isEmpty) throw Exception('No callId returned');

      if (mounted) {
        context.push('/call', extra: {
          'host': widget.host,
          'isVideo': isVideo,
          'callId': callId,
          'isCaller': true,
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        AppSnackBar.error(context, ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero image appbar
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                backgroundColor: AppColors.background,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: _isTogglingFollow
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(
                                _isFollowing
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _isFollowing
                                    ? Colors.redAccent
                                    : Colors.white,
                                size: 20),
                        onPressed: _toggleFollow,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 20),
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'report') {
                            ReportDialog.show(
                              context,
                              targetType: 'host',
                              targetId: widget.host.userId,
                              targetName: widget.host.name,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                const Icon(Icons.flag_rounded,
                                    color: AppColors.callRed, size: 18),
                                const SizedBox(width: 10),
                                Text('Report',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: AppColors.callRed)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (host.avatar != null)
                        // Hero tag matches host_card.dart for smooth morph transition
                        Hero(
                          tag: 'host_avatar_${host.id}',
                          child: Image.network(host.avatar!, fit: BoxFit.cover),
                        )
                      else
                        Container(color: AppColors.cardLight),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, AppColors.background],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + gender/age + online
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(host.name,
                                    style: AppTextStyles.displayMedium),
                                if (host.gender != null || host.age != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        if (host.gender != null) ...[
                                          Text(
                                            host.gender == 'male'
                                                ? '👨 Male'
                                                : host.gender == 'female'
                                                    ? '👩 Female'
                                                    : '⚧ Other',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color:
                                                        AppColors.textSecondary),
                                          ),
                                        ],
                                        if (host.gender != null &&
                                            host.age != null)
                                          Text('  ·  ',
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                      color:
                                                          AppColors.textHint)),
                                        if (host.age != null)
                                          Text(
                                            '${host.age} yrs',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color:
                                                        AppColors.textSecondary),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          OnlineBadge(isOnline: host.isOnline, showLabel: true),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating + stats row
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: host.rating,
                            itemSize: 16,
                            itemBuilder: (_, _) => const Icon(
                                Icons.star_rounded, color: AppColors.gold),
                          ),
                          const SizedBox(width: 6),
                          Text(host.rating.toStringAsFixed(1),
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.gold)),
                          const SizedBox(width: 16),
                          const Icon(Icons.call_rounded,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text('${host.totalCalls} calls',
                              style: AppTextStyles.bodySmall),
                          const SizedBox(width: 16),
                          const Icon(Icons.people_rounded,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text('${host.followersCount}',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Languages
                      Wrap(
                        spacing: 8,
                        children: host.languages
                            .map((lang) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(lang,
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.primary)),
                                ))
                            .toList(),
                      ),

                      // Interests / Tags
                      if (host.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Interests', style: AppTextStyles.headingSmall),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: host.tags
                              .map((tag) => ActionChip(
                                    label: Text('#$tag'),
                                    labelStyle:
                                        AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    onPressed: () {},
                                  ))
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Bio
                      Text('About', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 8),
                      Text(host.bio, style: AppTextStyles.bodyMedium),

                      const SizedBox(height: 24),

                      // Pricing cards
                      Text('Call Rates', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PriceCard(
                              icon: Icons.call_rounded,
                              label: 'Audio Call',
                              price: '₹${host.audioRatePerMin.toInt()}/min',
                              color: AppColors.callGreen,
                              onTap: () => _startCall(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PriceCard(
                              icon: Icons.videocam_rounded,
                              label: 'Video Call',
                              price: '₹${host.videoRatePerMin.toInt()}/min',
                              color: AppColors.primary,
                              onTap: () => _startCall(true),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Message + Gift buttons row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/chat/${host.id}',
                                  extra: host),
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                                minimumSize:
                                    const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => GiftPickerSheet.show(
                              context, ref,
                              hostId: host.id,
                              hostName: host.name,
                            ),
                            icon: const Icon(
                                Icons.card_giftcard_rounded,
                                size: 18),
                            label: const Text('Gift'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(
                                  color: AppColors.gold),
                              minimumSize:
                                  const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Subscribe + Watch Live buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubscribing ? null : _toggleSubscribe,
                              icon: _isSubscribing
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(
                                      _isSubscribed
                                          ? Icons.check_circle_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18),
                              label: Text(_isSubscribed ? 'Subscribed ✓' : 'Subscribe ₹99/mo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _isSubscribed
                                    ? AppColors.callGreen
                                    : AppColors.accent,
                                side: BorderSide(
                                    color: _isSubscribed
                                        ? AppColors.callGreen
                                        : AppColors.accent),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          if (_activeStream != null) ...[
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WatchStreamScreen(
                                    streamId: _activeStream!['id'].toString(),
                                    hostName: widget.host.name,
                                    title: _activeStream!['title'] as String? ?? 'Live',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.live_tv_rounded,
                                  color: Colors.white, size: 18),
                              label: const Text('Watch Live',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.callRed,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Audio + Video call buttons side by side
                      Row(
                        children: [
                          Expanded(
                            child: _CallActionButton(
                              icon: Icons.call_rounded,
                              label: 'Audio Call',
                              price: '₹${host.audioRatePerMin.toInt()}/min',
                              color: AppColors.callGreen,
                              onTap: _isStartingCall
                                  ? null
                                  : () => _startCall(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CallActionButton(
                              icon: Icons.videocam_rounded,
                              label: 'Video Call',
                              price: '₹${host.videoRatePerMin.toInt()}/min',
                              color: AppColors.primary,
                              onTap: _isStartingCall
                                  ? null
                                  : () => _startCall(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Reviews section ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  child: _ReviewsSection(
                    reviews: _reviews,
                    totalReviews: _totalReviews,
                    avgRating: widget.host.rating,
                    isLoading: _reviewsLoading,
                  ),
                ),
              ),
            ],
          ),

          // Full-screen loading overlay while initiating call
          if (_isStartingCall)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Starting call...',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  final int totalReviews;
  final double avgRating;
  final bool isLoading;

  const _ReviewsSection({
    required this.reviews,
    required this.totalReviews,
    required this.avgRating,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppColors.primaryGradient.createShader(b),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text('Reviews', style: AppTextStyles.headingSmall),
            const Spacer(),
            if (totalReviews > 0)
              Text(
                '$totalReviews reviews',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Rating summary card
        if (!isLoading && avgRating > 0)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Big number
                Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          const LinearGradient(
                            colors: [AppColors.gold, Color(0xFFFFB300)],
                          ).createShader(b),
                      child: Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    RatingBarIndicator(
                      rating: avgRating,
                      itemSize: 16,
                      itemBuilder: (_, _) => const Icon(
                          Icons.star_rounded, color: AppColors.gold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews ratings',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Star breakdown bars
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final star = 5 - i;
                      final count = reviews
                          .where((r) => r.rating.round() == star)
                          .length;
                      final frac = reviews.isEmpty
                          ? 0.0
                          : count / reviews.length;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$star',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textHint,
                                    fontSize: 10)),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 10),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.gold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

        // Loading state
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        // Empty state
        else if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.star_outline_rounded,
                      size: 44,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 10),
                  Text('No reviews yet',
                      style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to call and leave a review!',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        // Review cards
        else
          ...reviews.map((r) => _ReviewCard(review: r)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: review.reviewerAvatar != null
                    ? NetworkImage(review.reviewerAvatar!)
                    : null,
                child: review.reviewerAvatar == null
                    ? Text(
                        review.reviewerName.substring(0, 1).toUpperCase(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName,
                        style: AppTextStyles.labelMedium),
                    if (review.createdAt != null)
                      Text(
                        DateFormat('dd MMM yyyy').format(review.createdAt!),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
              // Star rating
              RatingBarIndicator(
                rating: review.rating,
                itemSize: 14,
                itemBuilder: (_, _) =>
                    const Icon(Icons.star_rounded, color: AppColors.gold),
              ),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 10),
            Text(review.comment!, style: AppTextStyles.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ── Bottom call action button ─────────────────────────────────────────────────

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String price;
  final Color color;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.price,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : AppColors.border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: Colors.white)),
            Text(price,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                )),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String price;
  final Color color;
  final VoidCallback onTap;

  const _PriceCard({
    required this.icon,
    required this.label,
    required this.price,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(price,
                style: AppTextStyles.labelLarge.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
