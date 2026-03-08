import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gradient_button.dart';

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  const _OnboardingPage(this.emoji, this.title, this.subtitle);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage('💬', 'Talk to Real People',
        'Connect with hosts through audio & video calls.\nReal conversations, real connections.'),
    _OnboardingPage('🎯', 'Find Your Perfect Host',
        'Browse hundreds of hosts by language,\ninterest and price. Someone for everyone.'),
    _OnboardingPage('💰', 'Pay Only for What You Use',
        'Load your wallet and pay per minute.\nNo subscriptions. No hidden charges.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Skip',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                ),
              ),

              // Dots + Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _controller,
                      count: _pages.length,
                      effect: ExpandingDotsEffect(
                        activeDotColor: AppColors.primary,
                        dotColor: AppColors.border,
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GradientButton(
                      label: _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onTap: () {
                        if (_currentPage == _pages.length - 1) {
                          context.go('/login');
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in glowing circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(page.emoji,
                  style: const TextStyle(fontSize: 70)),
            ),
          ),
          const SizedBox(height: 48),
          Text(page.title,
              style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(page.subtitle,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
