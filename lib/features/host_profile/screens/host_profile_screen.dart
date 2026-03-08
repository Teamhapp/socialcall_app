import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/online_badge.dart';

class HostProfileScreen extends StatefulWidget {
  final HostModel host;
  const HostProfileScreen({super.key, required this.host});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {
  bool _isStartingCall = false;

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
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final callId = data['callId'] as String;

      if (mounted) {
        context.go('/call', extra: {
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
                        icon: const Icon(Icons.favorite_border_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (host.avatar != null)
                        Image.network(host.avatar!, fit: BoxFit.cover)
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
                            itemBuilder: (_, __) => const Icon(
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
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.3)),
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

                      // Message button
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/chat/${host.id}', extra: host),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Send Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      GradientButton(
                        label:
                            'Audio Call  ₹${host.audioRatePerMin.toInt()}/min',
                        icon: const Icon(Icons.call_rounded,
                            color: Colors.white, size: 18),
                        onTap: () => _startCall(false),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
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
