import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/room_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_shell.dart';
import '../features/profile/profile_screen.dart';
import '../features/room/room_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/start/start_screen.dart';
import '../features/today/today_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) {
      final loggedIn = auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const StartScreen()),
      GoRoute(
        path: '/scan/:mode',
        builder: (_, state) => ScanScreen(
          mode: AnalyzeMode.values.asNameMap()[state.pathParameters['mode']] ?? AnalyzeMode.register,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/room', builder: (_, _) => const RoomScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});

/// auth 상태가 바뀔 때마다 go_router의 redirect를 다시 돌린다.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
