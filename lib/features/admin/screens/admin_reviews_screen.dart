import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/admin_empty_state.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<AdminReview> _reviews = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _reviews = [];
    }
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'page': _page,
        'limit': 20,
        if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
      };
      final raw = await AdminApi.get(ApiEndpoints.adminReviews, queryParameters: params);
      final data = AdminApi.parseData(raw);
      final list = (data['reviews'] as List? ?? data as List? ?? [])
          .map((e) => AdminReview.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _reviews = reset ? list : [..._reviews, ...list];
        _hasMore = list.length == 20;
        _page++;
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(AdminReview review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Review', style: AppTextStyles.headingSmall),
        content: Text(
          'Delete ${review.rating}★ review by ${review.userName} for ${review.hostName}?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.callRed))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AdminApi.delete(ApiEndpoints.adminReview(review.id));
      if (mounted) {
        AppSnackBar.success(context, 'Review deleted');
        setState(() => _reviews.removeWhere((r) => r.id == review.id));
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Reviews', style: AppTextStyles.headingSmall),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: AppTextStyles.bodyMedium,
              onChanged: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Search by host name…',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint, size: 20),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _load(reset: true),
              child: _reviews.isEmpty && !_hasMore && !_loading
                  ? const AdminEmptyState(
                      icon: Icons.rate_review_outlined,
                      message: 'No reviews found',
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _reviews.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _reviews.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2)),
                          );
                        }
                        final r = _reviews[i];
                        return _ReviewTile(
                          review: r,
                          onDelete: () => _delete(r),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final AdminReview review;
  final VoidCallback onDelete;
  const _ReviewTile({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              // Stars
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${review.userName} → ${review.hostName}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textHint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.callRed, size: 18),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text(_formatDate(review.createdAt),
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
