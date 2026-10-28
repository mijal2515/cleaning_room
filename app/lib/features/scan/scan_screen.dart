import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../data/room_repository.dart';
import '../today/today_providers.dart';

/// 사진을 찍는 곳은 여기 하나다: 처음 방 등록, 주간 점검, "오늘 너무 지저분해".
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.mode});

  final AnalyzeMode mode;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  Uint8List? _image;
  bool _busy = false;
  String? _error;

  (String, String) get _copy => switch (widget.mode) {
        AnalyzeMode.register => (
            '내 방 등록',
            '방 전체가 보이게 한 장만 찍어주세요. 처음 한 번이면 돼요. 매일 할 일은 사진 없이 골라 드려요.',
          ),
        AnalyzeMode.weekly => ('주간 점검', '방이 많이 달라졌다면 다시 찍어주세요. 구역과 할 일을 새로 정리해요.'),
        AnalyzeMode.now => ('오늘 너무 지저분해', '지금 모습을 찍으면 가장 달라 보일 3가지를 골라 드려요.'),
      };

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final analysis = await ref.read(roomRepositoryProvider).analyze(_image!, widget.mode);
      ref.read(aiPlanProvider.notifier).set(analysis);
      ref.invalidate(hotspotsProvider);
      if (mounted) context.go('/today');
    } on AnalyzeException catch (e) {
      setState(() => _error = _messageFor(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(AnalyzeFailure reason) => switch (reason) {
        AnalyzeFailure.dailyLimit => '오늘 사진 분석은 다 썼어요. 내일 다시 해주세요.',
        AnalyzeFailure.notRoom => '방이 잘 안 보여요. 밝은 곳에서 방 전체가 나오게 다시 찍어주세요.',
        AnalyzeFailure.refused => '이 사진은 분석할 수 없어요. 다른 사진으로 해주세요.',
        AnalyzeFailure.network => '인터넷 연결을 확인해주세요.',
        AnalyzeFailure.server => '잠시 문제가 생겼어요. 조금 뒤에 다시 해주세요.',
      };

  @override
  Widget build(BuildContext context) {
    final (title, guide) = _copy;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(guide),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _image == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHigh,
                        child: Icon(Icons.photo_camera_outlined, size: 56, color: colors.onSurfaceVariant),
                      )
                    : Image.memory(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('찍기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('앨범에서'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _image == null || _busy ? null : _analyze,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('할 일 받기'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
