import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/storage_service.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/host_profile/screens/host_profile_screen.dart';
import '../../features/call/screens/call_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/help/screens/help_screen.dart';
import '../../features/host_management/screens/become_host_screen.dart';
import '../../features/host_management/screens/host_dashboard_screen.dart';
import '../../features/host_management/screens/kyc_screen.dart';
import '../../features/call_history/screens/call_history_screen.dart';
import '../../features/following/screens/following_screen.dart';
import '../../models/host_model.dart';

const _publicRoutes = ['/splash', '/onboarding', '/login', '/otp', '/register'];

class AppRouter {
  // ── Slide-in transition for secondary screens ─────────────────────────────
  static CustomTransitionPage<void> _slide(
    GoRouterState state,
    Widget child,
  ) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        ),
      );

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (_, state) async {
      final path = state.matchedLocation;
      final isPublic = _publicRoutes.any((r) => path.startsWith(r));
      if (isPublic) return null;
      final loggedIn = await StorageService.isLoggedIn();
      if (!loggedIn) return '/login';
      return null;
    },
    routes: [
      // ── Auth / onboarding (default transitions) ───────────────────────────
      GoRoute(path: '/splash',      builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding',  builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login',       builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpScreen(phone: (state.extra as String?) ?? ''),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/home',     builder: (_, _) => const HomeScreen()),

      // ── Secondary screens (slide transition) ──────────────────────────────
      GoRoute(
        path: '/host/:id',
        pageBuilder: (_, state) {
          final host = state.extra;
          if (host is! HostModel) {
            return _slide(
              state,
              const Scaffold(
                  body: Center(child: Text('Host data unavailable'))),
            );
          }
          return _slide(state, HostProfileScreen(host: host));
        },
      ),
      GoRoute(
        path: '/call',
        pageBuilder: (_, state) {
          final args = state.extra;
          if (args is! Map<String, dynamic>) {
            return _slide(
              state,
              const Scaffold(
                  body: Center(child: Text('Invalid call parameters'))),
            );
          }
          final host = args['host'];
          if (host is! HostModel) {
            return _slide(
              state,
              const Scaffold(
                  body: Center(child: Text('Invalid call parameters'))),
            );
          }
          return _slide(
            state,
            CallScreen(
              host: host,
              isVideo: args['isVideo'] as bool? ?? false,
              callId: args['callId']?.toString() ?? '',
              isCaller: args['isCaller'] as bool? ?? true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/chat/:hostId',
        pageBuilder: (_, state) {
          final host = state.extra;
          if (host is! HostModel) {
            return _slide(
              state,
              const Scaffold(
                  body: Center(child: Text('Host data unavailable'))),
            );
          }
          return _slide(state, ChatScreen(host: host));
        },
      ),
      GoRoute(
        path: '/wallet',
        pageBuilder: (_, state) => _slide(state, const WalletScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _slide(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (_, state) => _slide(state, const HelpScreen()),
      ),
      GoRoute(
        path: '/become-host',
        pageBuilder: (_, state) => _slide(state, const BecomeHostScreen()),
      ),
      GoRoute(
        path: '/host-dashboard',
        pageBuilder: (_, state) => _slide(state, const HostDashboardScreen()),
      ),
      GoRoute(
        path: '/call-history',
        pageBuilder: (_, state) => _slide(state, const CallHistoryScreen()),
      ),
      GoRoute(
        path: '/following',
        pageBuilder: (_, state) => _slide(state, const FollowingScreen()),
      ),
      GoRoute(
        path: '/kyc',
        pageBuilder: (_, state) => _slide(state, const KycScreen()),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.error}')),
    ),
  );
}
