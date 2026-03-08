import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/incoming_call_provider.dart';
import 'core/router/app_router.dart';
import 'core/socket/socket_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/incoming_call_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      // _AppShell sits above every route — handles socket lifecycle and the
      // global incoming-call overlay so calls ring on ANY screen.
      builder: (_, child) => _AppShell(child: child!),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppShell
//
// • Connects / disconnects the WebSocket in sync with auth state.
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
    // If the user was already authenticated when the app launched (restored
    // from storage), connect the socket after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        _connectAndListen();
      }
    });
  }

  Future<void> _connectAndListen() async {
    await SocketService.connect();
    ref.read(incomingCallProvider.notifier).startListening();
  }

  void _disconnectAndStop() {
    ref.read(incomingCallProvider.notifier).stopListening();
    ref.read(incomingCallProvider.notifier).dismiss();
    SocketService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    // React to login / logout transitions anywhere in the app.
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasAuth = prev?.isAuthenticated ?? false;
      final isAuth  = next.isAuthenticated;

      if (isAuth && !wasAuth) {
        // User just logged in → bring socket up and start listening.
        _connectAndListen();
      } else if (!isAuth && wasAuth) {
        // User just logged out → tear everything down.
        _disconnectAndStop();
      }
    });

    return IncomingCallOverlay(child: widget.child);
  }
}
