import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/incoming_call_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/call_notification_service.dart';
import 'core/services/firebase_service.dart';
import 'core/socket/socket_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/incoming_call_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CallNotificationService.init();
  // Init Firebase + FCM (graceful — won't crash if google-services.json missing)
  await FirebaseService.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: SocialCallApp()));
}

class SocialCallApp extends StatelessWidget {
  const SocialCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SocialCall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      builder: (_, child) => _AppShell(child: child!),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppShell
//
// • Connects / disconnects the WebSocket in sync with auth state.
// • Registers FCM token with backend after login.
// • Starts / stops the IncomingCallNotifier socket listeners accordingly.
// • Wraps the entire screen tree with IncomingCallOverlay so incoming-call
//   UI appears on top of any screen the user is currently viewing.
// ─────────────────────────────────────────────────────────────────────────────

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        _connectAndListen();
      }
    });
  }

  Future<void> _connectAndListen() async {
    await SocketService.connect();
    ref.read(incomingCallProvider.notifier).startListening();
    // Register FCM token so push notifications reach this device
    await FirebaseService.registerToken();
  }

  void _disconnectAndStop() {
    ref.read(incomingCallProvider.notifier).stopListening();
    ref.read(incomingCallProvider.notifier).dismiss();
    SocketService.disconnect();
    // Remove FCM token from backend on logout
    FirebaseService.deleteToken();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasAuth = prev?.isAuthenticated ?? false;
      final isAuth  = next.isAuthenticated;

      if (isAuth && !wasAuth) {
        _connectAndListen();
      } else if (!isAuth && wasAuth) {
        _disconnectAndStop();
      }
    });

    return IncomingCallOverlay(child: widget.child);
  }
}
