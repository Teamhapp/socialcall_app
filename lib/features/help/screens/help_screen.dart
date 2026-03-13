import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _expandedFaq = -1;
  String _faqQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text('Help & Support', style: AppTextStyles.headingMedium),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contact'),
            Tab(text: 'Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FaqTab(
            expandedIndex: _expandedFaq,
            query: _faqQuery,
            onExpand: (i) => setState(() => _expandedFaq = _expandedFaq == i ? -1 : i),
            onSearch: (q) => setState(() {
              _faqQuery = q;
              _expandedFaq = -1;
            }),
          ),
          const _ContactTab(),
          const _ReportTab(),
        ],
      ),
    );
  }
}

// ── FAQ Tab ───────────────────────────────────────────────────────────────────

class _FaqTab extends StatelessWidget {
  final int expandedIndex;
  final String query;
  final ValueChanged<int> onExpand;
  final ValueChanged<String> onSearch;

  const _FaqTab({
    required this.expandedIndex,
    required this.query,
    required this.onExpand,
    required this.onSearch,
  });

  static const _faqs = [
    (
      'How do I recharge my wallet?',
      'Go to the Wallet tab → tap Recharge → choose an amount → pay via Razorpay using UPI, card, or net banking. Balance is added instantly.',
    ),
    (
      'How are calls charged?',
      'Calls are charged per minute based on the host\'s rate (shown on their profile). Your wallet is deducted in real-time during the call. You\'ll get a low-balance warning when you have less than 1 minute left.',
    ),
    (
      'How do I become a host?',
      'Go to Profile → tap "Become a Host" → fill in your bio, languages, and set your rate per minute → toggle online when you\'re ready to receive calls.',
    ),
    (
      'Can I get a refund for unused balance?',
      'Wallet balance is non-refundable as per our Terms of Service. However, if you were charged for a call that didn\'t connect, contact support within 24 hours.',
    ),
    (
      'What happens if my internet disconnects during a call?',
      'The call will automatically end and you\'ll only be charged for the time connected. You can call again immediately.',
    ),
    (
      'How do I send a gift?',
      'During a call, tap the gift icon and select a gift. The amount is deducted from your wallet and sent to the host instantly.',
    ),
    (
      'How do hosts receive their earnings?',
      'Host earnings (65% of call charges after platform commission) are credited to their host wallet. They can request withdrawal every Monday to their bank account.',
    ),
    (
      'Is my call private?',
      'Yes! All calls are peer-to-peer encrypted using WebRTC. We do not record or store call audio/video.',
    ),
    (
      'How do I block someone?',
      'Go to Settings → Privacy → Blocked Users → add a number. Blocked users cannot call or message you.',
    ),
    (
      'Why is my OTP not arriving?',
      'Check if your number has DND enabled. Try again after 10 minutes. If it still fails, contact support with your phone number.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Filter FAQs by search query
    final filtered = query.isEmpty
        ? _faqs.asMap().entries.toList()
        : _faqs.asMap().entries.where((e) {
            final q = query.toLowerCase();
            return e.value.$1.toLowerCase().contains(q) ||
                e.value.$2.toLowerCase().contains(q);
          }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            onChanged: onSearch,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search questions...',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textHint, size: 18),
                      onPressed: () => onSearch(''),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(
            child: Text('No matching questions found.',
                style: TextStyle(color: AppColors.textHint)),
          ),
        ] else ...[
        Text('Frequently Asked Questions',
            style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        ...filtered.map((e) {
          final i = e.key;
          final faq = e.value;
          final isExpanded = expandedIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onExpand(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppColors.primary.withOpacity(0.08)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExpanded ? AppColors.primary.withOpacity(0.4) : AppColors.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(faq.$1,
                                style: AppTextStyles.labelLarge.copyWith(
                                    color: isExpanded
                                        ? AppColors.primary
                                        : AppColors.textPrimary)),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: isExpanded
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          color: AppColors.border,
                          margin: const EdgeInsets.only(bottom: 12),
                        ),
                        Text(faq.$2, style: AppTextStyles.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        ], // end else
      ],
    );
  }
}

// ── Contact Tab ───────────────────────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  const _ContactTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),

        // Response time banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fast Support',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: Colors.white)),
                    Text('Average response time: 2 hours',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('Reach us on', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),

        _ContactCard(
          emoji: '💬',
          title: 'WhatsApp Support',
          subtitle: 'Chat with us instantly',
          detail: '+91 98765 43200',
          color: const Color(0xFF25D366),
          onTap: () => launchUrl(
            Uri.parse('https://wa.me/919876543200'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 10),
        _ContactCard(
          emoji: '📧',
          title: 'Email Support',
          subtitle: 'We reply within 24 hours',
          detail: 'support@socialcall.app',
          color: AppColors.accent,
          onTap: () => launchUrl(
            Uri.parse('mailto:support@socialcall.app?subject=SocialCall%20Support'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 10),
        _ContactCard(
          emoji: '📸',
          title: 'Instagram',
          subtitle: 'Follow us for updates',
          detail: '@socialcall.app',
          color: const Color(0xFFE1306C),
          onTap: () => launchUrl(
            Uri.parse('https://instagram.com/socialcall.app'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 10),
        _ContactCard(
          emoji: '🐦',
          title: 'Twitter / X',
          subtitle: 'Tweet your issue for fast help',
          detail: '@SocialCallApp',
          color: const Color(0xFF1DA1F2),
          onTap: () => launchUrl(
            Uri.parse('https://twitter.com/SocialCallApp'),
            mode: LaunchMode.externalApplication,
          ),
        ),

        const SizedBox(height: 24),
        Text('Support Hours', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _HoursRow(day: 'Monday – Friday', time: '9:00 AM – 9:00 PM'),
              const SizedBox(height: 8),
              _HoursRow(day: 'Saturday', time: '10:00 AM – 6:00 PM'),
              const SizedBox(height: 8),
              _HoursRow(day: 'Sunday', time: 'WhatsApp only'),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.detail,
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
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: AppTextStyles.caption.copyWith(color: color,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String day;
  final String time;
  const _HoursRow({required this.day, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(day, style: AppTextStyles.bodyMedium)),
        Text(time,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primary)),
      ],
    );
  }
}

// ── Report Tab ────────────────────────────────────────────────────────────────

class _ReportTab extends StatefulWidget {
  const _ReportTab();

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  String _selectedCategory = 'Technical Issue';
  final _descCtrl = TextEditingController();
  bool _submitted = false;

  final _categories = [
    'Technical Issue',
    'Payment Problem',
    'Host Misconduct',
    'Account Issue',
    'App Crash',
    'Other',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.online.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.online, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Report Submitted!',
                  style: AppTextStyles.headingMedium),
              const SizedBox(height: 8),
              Text(
                'Thank you for reporting. Our team will review it within 24 hours.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => setState(() {
                  _submitted = false;
                  _descCtrl.clear();
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                child: Text('Report Another',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Text('Report an Issue', style: AppTextStyles.headingSmall),
        const SizedBox(height: 4),
        Text('Help us improve by reporting bugs or inappropriate content.',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 20),

        // Category
        Text('Category', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((c) {
            final sel = c == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(c,
                    style: AppTextStyles.caption.copyWith(
                      color: sel ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Description
        Text('Describe the issue', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _descCtrl,
            maxLines: 5,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Please describe what happened in detail...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Attach screenshot hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Include as much detail as possible to help us resolve it quickly.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () {
            if (_descCtrl.text.length < 10) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please describe the issue (min 10 characters)'),
                  backgroundColor: AppColors.callRed,
                ),
              );
              return;
            }
            setState(() => _submitted = true);
          },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
