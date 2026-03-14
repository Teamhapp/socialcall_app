import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/online_badge.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<HostModel> _hosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
                      itemBuilder: (_, i) => _FollowingTile(host: _hosts[i]),
                    ),
            ),
    );
  }
}

class _FollowingTile extends StatelessWidget {
  final HostModel host;
  const _FollowingTile({required this.host});

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
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: host.avatar == null
                      ? const Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 28)
                      : null,
                ),
                if (host.isOnline)
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(
                      width: 10, height: 10,
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
                        itemBuilder: (_, __) => const Icon(
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
                ],
              ),
            ),
            // Rate + call button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${host.audioRatePerMin.toInt()}/min',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: host.isOnline
                      ? () => context.push('/host/${host.id}', extra: host)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: host.isOnline
                          ? AppColors.primaryGradient
                          : null,
                      color: host.isOnline ? null : AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      host.isOnline ? 'Call' : 'Offline',
                      style: AppTextStyles.caption.copyWith(
                        color: host.isOnline
                            ? Colors.white
                            : AppColors.textHint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
