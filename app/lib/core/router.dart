import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/room_repository.dart';
import '../features/home/home_shell.dart';
import '../features/profile/profile_screen.dart';
import '../features/room/room_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/start/start_screen.dart';
import '../features/today/today_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
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
  return router;
});
