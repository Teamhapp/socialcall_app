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
import '../../features/call_history/screens/call_history_screen.dart';
import '../../features/following/screens/following_screen.dart';
import '../../models/host_model.dart';

const _publicRoutes = ['/splash', '/onboarding', '/login', '/otp', '/register'];

class AppRouter {
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
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/host/:id',
        builder: (_, state) => HostProfileScreen(host: state.extra as HostModel),
      ),
      GoRoute(
        path: '/call',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>;
          return CallScreen(
            host: args['host'] as HostModel,
            isVideo: args['isVideo'] as bool,
            callId: args['callId'] as String,
            isCaller: args['isCaller'] as bool,
          );
        },
      ),
      GoRoute(
        path: '/chat/:hostId',
        builder: (_, state) => ChatScreen(host: state.extra as HostModel),
      ),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/become-host', builder: (_, __) => const BecomeHostScreen()),
      GoRoute(path: '/host-dashboard', builder: (_, __) => const HostDashboardScreen()),
      GoRoute(path: '/call-history', builder: (_, __) => const CallHistoryScreen()),
      GoRoute(path: '/following', builder: (_, __) => const FollowingScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.error}')),
    ),
  );
}
