import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/online_badge.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<HostModel> _hosts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _callingHostId;  // tracks which host is being called
  String? _unfollowingId;  // tracks which host is being unfollowed

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Start audio / video call ──────────────────────────────────────────────

  Future<void> _startCall(HostModel host, bool isVideo) async {
    if (_callingHostId != null) return;
    setState(() => _callingHostId = host.id);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.callInitiate,
        data: {'hostId': host.id, 'callType': isVideo ? 'video' : 'audio'},
      );
      final data = ApiClient.parseData(resp) as Map<String, dynamic>?;
      final callId = data?['callId']?.toString() ?? '';
      if (callId.isEmpty) throw Exception('No callId returned');
      if (mounted) {
        context.push('/call', extra: {
          'host': host,
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
      if (mounted) setState(() => _callingHostId = null);
    }
  }

  // ── Unfollow ──────────────────────────────────────────────────────────────

  Future<void> _unfollow(HostModel host) async {
    if (_unfollowingId != null) return;
    setState(() => _unfollowingId = host.id);
    try {
      await ApiClient.dio.delete(
        ApiEndpoints.hostFollow(host.id),
      );
      if (mounted) {
        setState(() {
          _hosts.removeWhere((h) => h.id == host.id);
          _unfollowingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed ${host.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _unfollowingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.hostFollowing);
      final raw = ApiClient.parseData(resp) as List? ?? [];
      if (mounted) {
        setState(() {
          _hosts = raw
              .cast<Map<String, dynamic>>()
              .map(HostModel.fromJson)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Following', style: AppTextStyles.headingMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text('Could not load',
                            style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 8),
                        Text('Check your connection and try again.',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        GradientButton(
                            label: 'Retry', onTap: _load, height: 44),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _hosts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_border_rounded,
                                size: 52, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text('Not following anyone yet',
                                style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the ❤️ on a host profile to follow them.',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _hosts.length,
                      itemBuilder: (_, i) {
                        final host = _hosts[i];
                        // ── Swipe right = audio call; left = unfollow ──
                        return Dismissible(
                          key: Key('following_${host.id}'),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: AppColors.callGreen.withValues(alpha: 0.15),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.call_rounded,
                                    color: AppColors.callGreen),
                                const SizedBox(width: 8),
                                Text('Audio Call',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.callGreen)),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppColors.primary.withValues(alpha: 0.15),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Unfollow',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary)),
                                const SizedBox(width: 8),
                                Icon(Icons.person_remove_rounded,
                                    color: AppColors.primary),
                              ],
                            ),
                          ),
                          confirmDismiss: (dir) async {
                            if (dir == DismissDirection.startToEnd) {
                              // Audio call — don't remove the tile
                              if (host.isOnline && _callingHostId == null) {
                                _startCall(host, false);
                              } else if (!host.isOnline) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${host.name} is offline'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              return false;
                            }
                            // Unfollow swipe — show confirm dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: Text('Unfollow ${host.name}?',
                                    style: AppTextStyles.headingSmall),
                                content: Text(
                                  'You will no longer receive notifications when ${host.name} goes online.',
                                  style: AppTextStyles.bodySmall,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: Text('Unfollow',
                                        style: TextStyle(
                                            color: AppColors.primary)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _unfollow(host);
                            }
                            return false; // _unfollow handles removal
                          },
                          onDismissed: (_) {},
                          child: _FollowingTile(
                            host: host,
                            callingHostId: _callingHostId,
                            onCall: _startCall,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  // ── Shimmer skeleton ─────────────────────────────────────────────────────────

  Widget _buildSkeleton() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: AppColors.card,
          highlightColor: AppColors.cardLight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 28, backgroundColor: AppColors.cardLight),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 13,
                          width: 120,
                          color: AppColors.cardLight),
                      const SizedBox(height: 6),
                      Container(
                          height: 10,
                          width: 80,
                          color: AppColors.cardLight),
                      const SizedBox(height: 6),
                      Container(
                          height: 10,
                          width: 60,
                          color: AppColors.cardLight),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.cardLight,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.cardLight,
                          shape: BoxShape.circle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Following tile ────────────────────────────────────────────────────────────

class _FollowingTile extends StatelessWidget {
  final HostModel host;
  final String? callingHostId;
  final void Function(HostModel, bool) onCall;

  const _FollowingTile({
    required this.host,
    required this.callingHostId,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/host/${host.id}', extra: host),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar + online dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: host.avatar != null
                      ? NetworkImage(host.avatar!)
                      : null,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  child: host.avatar == null
                      ? const Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 28)
                      : null,
                ),
                if (host.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(host.name, style: AppTextStyles.labelLarge),
                      const SizedBox(width: 6),
                      if (host.isVerified)
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: host.rating,
                        itemSize: 12,
                        itemBuilder: (_, _) => const Icon(
                            Icons.star_rounded, color: AppColors.gold),
                      ),
                      const SizedBox(width: 4),
                      Text(host.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.gold)),
                      const SizedBox(width: 8),
                      OnlineBadge(isOnline: host.isOnline),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '← swipe to call  •  swipe to unfollow →',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint.withValues(alpha: 0.5),
                        fontSize: 9),
                  ),
                ],
              ),
            ),
            // Call buttons column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!host.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Offline',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuickCallBtn(
                        icon: Icons.call_rounded,
                        color: AppColors.callGreen,
                        tooltip: '₹${host.audioRatePerMin.toInt()}/min',
                        loading: callingHostId == host.id,
                        onTap: callingHostId == null
                            ? () => onCall(host, false)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _QuickCallBtn(
                        icon: Icons.videocam_rounded,
                        color: AppColors.primary,
                        tooltip: '₹${host.videoRatePerMin.toInt()}/min',
                        loading: callingHostId == host.id,
                        onTap: callingHostId == null
                            ? () => onCall(host, true)
                            : null,
                      ),
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

// ── Small circular call button ────────────────────────────────────────────────

class _QuickCallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool loading;
  final VoidCallback? onTap;

  const _QuickCallBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
