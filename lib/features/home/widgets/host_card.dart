import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/online_badge.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';

class HostCard extends StatelessWidget {
  final HostModel host;
  const HostCard({super.key, required this.host});

  // ── Long-press quick-action sheet ────────────────────────────────────────

  void _showQuickActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _QuickActionSheet(host: host),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/host/${host.id}', extra: host),
      onLongPress: () => _showQuickActions(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.card,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Avatar image — Hero tag enables morphing to HostProfileScreen
            Positioned.fill(
              child: Hero(
                tag: 'host_avatar_${host.id}',
                child: host.avatar != null
                    ? Image.network(
                        host.avatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.cardLight,
                          child: const Icon(Icons.person_rounded,
                              size: 60, color: AppColors.textHint),
                        ),
                      )
                    : Container(
                        color: AppColors.cardLight,
                        child: const Icon(Icons.person_rounded,
                            size: 60, color: AppColors.textHint),
                      ),
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.hostCardGradient,
                ),
              ),
            ),

            // Verified badge
            if (host.isVerified)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Colors.white, size: 12),
                ),
              ),

            // Online badge
            Positioned(
              top: 10,
              left: 10,
              child: OnlineBadge(isOnline: host.isOnline),
            ),

            // Long-press hint (subtle)
            Positioned(
              top: 10,
              right: host.isVerified ? 38 : 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert_rounded,
                    color: Colors.white70, size: 12),
              ),
            ),

            // Info at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      host.name,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 12),
                        const SizedBox(width: 2),
                        Text(host.rating.toStringAsFixed(1),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold)),
                        const Spacer(),
                        Text('₹${host.audioRatePerMin.toInt()}/min',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primaryLight)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Language chips
                    Wrap(
                      spacing: 4,
                      children: host.languages.take(2).map((lang) =>
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(lang,
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 9)),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Quick call buttons (audio + video) — visible only when online
            if (host.isOnline)
              Positioned(
                right: 8,
                bottom: 50,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio call
                    GestureDetector(
                      onTap: () =>
                          context.push('/host/${host.id}', extra: host),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.callGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.callGreen.withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Video call
                    GestureDetector(
                      onTap: () =>
                          context.push('/host/${host.id}', extra: host),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.videocam_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-action bottom sheet ─────────────────────────────────────────────────

class _QuickActionSheet extends StatefulWidget {
  final HostModel host;
  const _QuickActionSheet({required this.host});

  @override
  State<_QuickActionSheet> createState() => _QuickActionSheetState();
}

class _QuickActionSheetState extends State<_QuickActionSheet> {
  bool _calling = false;
  bool _following = false;
  bool _isFollowed = false; // optimistic — unknown without extra API call

  Future<void> _initiateCall(bool isVideo) async {
    if (_calling) return;
    Navigator.pop(context);
    setState(() => _calling = true);
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
      if (callId.isEmpty) throw Exception('No callId');
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
      if (mounted) setState(() => _calling = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_following) return;
    setState(() => _following = true);
    try {
      if (_isFollowed) {
        await ApiClient.dio.delete(ApiEndpoints.hostFollow(widget.host.id));
      } else {
        await ApiClient.dio.post(ApiEndpoints.hostFollow(widget.host.id));
      }
      if (mounted) {
        setState(() {
          _isFollowed = !_isFollowed;
          _following = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isFollowed ? 'Following ${widget.host.name}' : 'Unfollowed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(),

          // Host header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: host.avatar != null
                    ? NetworkImage(host.avatar!)
                    : null,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: host.avatar == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(host.name, style: AppTextStyles.headingSmall),
                        if (host.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                    Text(
                      host.isOnline ? 'Online now' : 'Offline',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: host.isOnline
                            ? AppColors.online
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Action tiles
          if (host.isOnline) ...[
            _ActionTile(
              icon: Icons.call_rounded,
              iconColor: AppColors.callGreen,
              label: 'Audio Call',
              subtitle: '₹${host.audioRatePerMin.toInt()}/min',
              onTap: _calling ? null : () => _initiateCall(false),
            ),
            _ActionTile(
              icon: Icons.videocam_rounded,
              iconColor: AppColors.primary,
              label: 'Video Call',
              subtitle: '₹${host.videoRatePerMin.toInt()}/min',
              onTap: _calling ? null : () => _initiateCall(true),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Text('${host.name} is currently offline',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),

          _ActionTile(
            icon: Icons.chat_bubble_rounded,
            iconColor: Colors.blueAccent,
            label: 'Message',
            subtitle: 'Open conversation',
            onTap: () {
              Navigator.pop(context);
              context.push('/chat/${host.id}', extra: host);
            },
          ),
          _ActionTile(
            icon: _isFollowed
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: Colors.pinkAccent,
            label: _isFollowed ? 'Unfollow' : 'Follow',
            subtitle: _isFollowed
                ? 'Stop following ${host.name}'
                : 'Get notified when ${host.name} goes online',
            onTap: _following ? null : _toggleFollow,
            loading: _following,
          ),
          _ActionTile(
            icon: Icons.person_rounded,
            iconColor: AppColors.textHint,
            label: 'View Profile',
            onTap: () {
              Navigator.pop(context);
              context.push('/host/${host.id}', extra: host);
            },
          ),
        ],
      ),
    );
  }
}

// ── Reusable action tile inside the quick-action sheet ────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: iconColor),
              )
            : Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyLarge),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint))
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
