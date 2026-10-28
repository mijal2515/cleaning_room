import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// 익명 로그인을 마치고, 방 프로필이 있으면 오늘 화면, 없으면 방 등록으로 보낸다.
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    if (boot case AsyncData(:final value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(value ? '/today' : '/scan/register');
      });
    }
    return Scaffold(
      body: Center(
        child: boot.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('연결하지 못했어요. 인터넷을 확인해주세요.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => ref.invalidate(bootstrapProvider), child: const Text('다시 시도')),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
