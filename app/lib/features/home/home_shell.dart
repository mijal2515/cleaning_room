import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sunny_friend.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            '청소 코치',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          const WaveRule(),
          Expanded(child: shell),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: const Color(0xFF24231F),
                  indicatorColor: const Color(0xFFFFD85B),
                  height: 76,
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      color: states.contains(WidgetState.selected)
                          ? const Color(0xFFFFD85B)
                          : const Color(0xFFFFFDF0),
                      fontSize: 12,
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? const Color(0xFF24231F)
                          : const Color(0xFFFFFDF0),
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline),
                      label: '오늘',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.cottage_outlined),
                      label: '내 방',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      label: '나의 기록',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
