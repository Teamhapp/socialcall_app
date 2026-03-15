import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _userCalls = [];
  List<Map<String, dynamic>> _hostCalls = [];
  bool _isLoading = true;
  String? _callingId; // tracks which call is being dialled back

  @override
  void initState() {
    super.initState();
    final isHost = ref.read(authProvider).user?.isHost ?? false;
    _tabController = TabController(length: isHost ? 2 : 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final isHost = ref.read(authProvider).user?.isHost ?? false;
      final futures = <Future>[
        ApiClient.dio.get(ApiEndpoints.callHistory),
        if (isHost) ApiClient.dio.get(ApiEndpoints.callHistoryHost),
      ];
      final results = await Future.wait(futures);
      if (mounted) {
        final rawUser = ApiClient.parseData(results[0]) as List? ?? [];
        setState(() {
          _userCalls = rawUser.cast<Map<String, dynamic>>();
          if (isHost && results.length > 1) {
            final rawHost = ApiClient.parseData(results[1]) as List? ?? [];
            _hostCalls = rawHost.cast<Map<String, dynamic>>();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Call back a host from history. Mirrors `_startCall` in FollowingScreen.
  Future<void> _callBack(Map<String, dynamic> call) async {
    final hostId = call['host_id'] as String? ?? '';
    if (hostId.isEmpty || _callingId != null) return;
    setState(() => _callingId = hostId);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.callInitiate,
        data: {'hostId': hostId, 'callType': 'audio'},
      );
      final data = ApiClient.parseData(resp) as Map<String, dynamic>?;
      final callId = data?['callId']?.toString() ?? '';
      if (callId.isEmpty) throw Exception('No callId returned');
      if (mounted) {
        final fakeHost = HostModel(
          id: hostId,
          userId: hostId,
          name: call['host_name'] as String? ?? 'Host',
          avatar: call['host_avatar'] as String?,
          bio: '',
          languages: const [],
          audioRatePerMin: 0,
          videoRatePerMin: 0,
          rating: 0,
          totalCalls: 0,
          isOnline: true,
          isVerified: false,
          followersCount: 0,
        );
        context.push('/call', extra: {
          'host': fakeHost,
          'isVideo': false,
          'callId': callId,
          'isCaller': true,
        });
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
      if (mounted) setState(() => _callingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = ref.watch(authProvider).user?.isHost ?? false;

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
        title: Text('Call History', style: AppTextStyles.headingMedium),
        bottom: isHost
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'My Calls'),
                  Tab(text: 'Received'),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppColors.border, height: 1),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: isHost
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _CallList(
                          calls: _userCalls,
                          asHost: false,
                          callingId: _callingId,
                          onCallBack: _callBack,
                          onRemove: (idx) => setState(
                              () => _userCalls.removeAt(idx)),
                        ),
                        _CallList(
                          calls: _hostCalls,
                          asHost: true,
                          callingId: _callingId,
                          onCallBack: _callBack,
                          onRemove: (idx) => setState(
                              () => _hostCalls.removeAt(idx)),
                        ),
                      ],
                    )
                  : _CallList(
                      calls: _userCalls,
                      asHost: false,
                      callingId: _callingId,
                      onCallBack: _callBack,
                      onRemove: (idx) =>
                          setState(() => _userCalls.removeAt(idx)),
                    ),
            ),
    );
  }
}

// ── Call list ─────────────────────────────────────────────────────────────────

class _CallList extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  final bool asHost;
  final String? callingId;
  final Future<void> Function(Map<String, dynamic>) onCallBack;
  final void Function(int) onRemove;

  const _CallList({
    required this.calls,
    required this.asHost,
    required this.callingId,
    required this.onCallBack,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_missed_rounded,
                  size: 52, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('No calls yet', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(
                asHost
                    ? 'Go online to start receiving calls!'
                    : 'Find a host and start your first call.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      itemBuilder: (_, i) {
        final call = calls[i];
        final hostId = call['host_id'] as String? ?? '';
        final isCallingThis = callingId == hostId;

        // ── Swipe right = call back; swipe left = hide ──────────────────
        return Dismissible(
          key: Key('call_${call['id'] ?? i}'),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            color: AppColors.callGreen.withValues(alpha: 0.15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_rounded, color: AppColors.callGreen),
                const SizedBox(width: 8),
                Text('Call Back',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.callGreen)),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.callRed.withValues(alpha: 0.15),
            child: const Icon(Icons.delete_outline_rounded,
                color: AppColors.callRed),
          ),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              if (!asHost && hostId.isNotEmpty && callingId == null) {
                await onCallBack(call);
              }
              return false; // don't remove the tile
            }
            return true; // allow hide
          },
          onDismissed: (_) => onRemove(i),
          child: _CallTile(
            call: call,
            asHost: asHost,
            isCallingBack: isCallingThis,
          ),
        );
      },
    );
  }
}

// ── Call tile ─────────────────────────────────────────────────────────────────

class _CallTile extends StatefulWidget {
  final Map<String, dynamic> call;
  final bool asHost;
  final bool isCallingBack;

  const _CallTile({
    required this.call,
    required this.asHost,
    required this.isCallingBack,
  });

  @override
  State<_CallTile> createState() => _CallTileState();
}

class _CallTileState extends State<_CallTile> {
  bool _rated = false;

  Future<void> _submitRating(double rating) async {
    try {
      await ApiClient.dio.post(
        ApiEndpoints.callReview(widget.call['id'] as String),
        data: {'rating': rating.toInt()},
      );
      setState(() => _rated = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback! ⭐'),
            backgroundColor: AppColors.callGreen,
          ),
        );
      }
    } catch (_) {}
  }

  void _showRateSheet() {
    double tempRating = 4;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Rate this call', style: AppTextStyles.headingMedium),
              const SizedBox(height: 20),
              RatingBar.builder(
                initialRating: tempRating,
                minRating: 1,
                itemSize: 44,
                itemBuilder: (_, _) =>
                    const Icon(Icons.star_rounded, color: AppColors.gold),
                onRatingUpdate: (r) => setS(() => tempRating = r),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitRating(tempRating);
                },
                child: const Text('Submit Rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call['call_type'] == 'video';
    final duration = widget.call['duration_seconds'] as int? ?? 0;
    final rawAmount = widget.call[
        widget.asHost ? 'host_earnings' : 'amount_charged'];
    final amount = rawAmount == null
        ? '0.00'
        : (rawAmount is num
                ? rawAmount
                : double.tryParse(rawAmount.toString()) ?? 0.0)
            .toStringAsFixed(2);
    final otherName = widget.asHost
        ? (widget.call['caller_name'] as String? ?? 'Unknown')
        : (widget.call['host_name'] as String? ?? 'Unknown');
    final otherAvatar = widget.asHost
        ? (widget.call['caller_avatar'] as String?)
        : (widget.call['host_avatar'] as String?);
    final createdAt = widget.call['created_at'] != null
        ? DateTime.tryParse(widget.call['created_at'] as String)
        : null;
    final hasReview = widget.call['has_review'] as bool? ?? false;
    final canRate =
        !widget.asHost && !hasReview && !_rated && duration > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: otherAvatar != null
                        ? NetworkImage(otherAvatar)
                        : null,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    child: otherAvatar == null
                        ? const Icon(Icons.person_rounded,
                            color: AppColors.primary, size: 24)
                        : null,
                  ),
                  if (widget.isCallingBack)
                    Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.callGreen),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherName, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isVideo
                                    ? AppColors.primary
                                    : AppColors.callGreen)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                size: 11,
                                color: isVideo
                                    ? AppColors.primary
                                    : AppColors.callGreen,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isVideo ? 'Video' : 'Audio',
                                style: AppTextStyles.caption.copyWith(
                                  color: isVideo
                                      ? AppColors.primary
                                      : AppColors.callGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}',
                          style: AppTextStyles.bodySmall,
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(createdAt),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.asHost ? '+₹$amount' : '-₹$amount',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: widget.asHost
                          ? AppColors.callGreen
                          : AppColors.callRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.asHost ? 'earned' : 'charged',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                        fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ],
          ),
          if (canRate) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showRateSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_outline_rounded,
                      color: AppColors.gold, size: 16),
                  const SizedBox(width: 6),
                  Text('Rate this call',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.gold)),
                ],
              ),
            ),
          ],
          // ── Swipe hint (first-time) ──────────────────────────────────
          if (!widget.asHost && duration > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe_rounded,
                    size: 12,
                    color: AppColors.textHint.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Swipe right to call back',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint.withValues(alpha: 0.5),
                      fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
