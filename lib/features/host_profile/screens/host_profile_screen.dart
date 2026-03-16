import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gift_picker_sheet.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/online_badge.dart';
import '../../live/screens/watch_stream_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkFollowing();
    _checkSubscription();
    _checkActiveStream();
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
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Subscribe'),
            content: Text('Subscribe to ${widget.host.name} for ₹99/month?\n\nThis will deduct 99 coins from your wallet.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Subscribe ₹99', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await ApiClient.dio.post(ApiEndpoints.subscribeHost(widget.host.id));
        if (mounted) setState(() => _isSubscribed = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Subscribed to ${widget.host.name}! ✓'),
                backgroundColor: AppColors.callGreen),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)),
              backgroundColor: AppColors.callRed),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e))),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.callRed,
          ),
        );
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
                      // Name + online
                      Row(
                        children: [
                          Expanded(
                            child: Text(host.name,
                                style: AppTextStyles.displayMedium),
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
