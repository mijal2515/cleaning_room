import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/providers.dart';
import '../../components/forest_scene.dart';
import '../../components/mochi_beaver.dart';

/// 이메일·비밀번호 로그인/가입. 성공하면 라우터 redirect가 앱으로 보낸다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해줘.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(roomRepositoryProvider);
    try {
      if (_signUp) {
        await repo.signUp(email, password);
      } else {
        await repo.signIn(email, password);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '연결하지 못했어. 인터넷을 확인해줘.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the artwork stable while the keyboard opens; the foreground scrolls.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final forestTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF315D43),
        brightness: Brightness.light,
      ),
    );
    return Theme(
      data: forestTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: ForestScene(
          child: SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 56, 24, keyboard + 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MochiBeaver(size: 112),
                          const Text('청소 코치', style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800,
                            color: Color(0xFF214C38), letterSpacing: -1,
                          )),
                          const SizedBox(height: 8),
                          const Text('작은 정리로, 나만의 쉼터를 가꿔요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF3D5D43), height: 1.5)),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDFDF5).withValues(alpha: .97),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0xFFE5EBD9)),
                              boxShadow: [BoxShadow(
                                color: const Color(0xFF183C2A).withValues(alpha: .12),
                                blurRadius: 32, offset: const Offset(0, 12),
                              )],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(_signUp ? '함께 시작해요' : '다시 만나서 반가워요',
                                  style: const TextStyle(fontSize: 20,
                                    fontWeight: FontWeight.w700, color: Color(0xFF294536))),
                                const SizedBox(height: 22),
                                TextField(
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: _fieldDecoration('이메일', 'name@example.com'),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _password,
                                  enabled: !_busy,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                                  onSubmitted: (_) => _busy ? null : _submit(),
                                  decoration: _fieldDecoration('비밀번호', '비밀번호를 입력해 주세요'),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Semantics(liveRegion: true, child: Text(_error!,
                                    style: TextStyle(color: forestTheme.colorScheme.error))),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF315D43),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(54),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                    ? const SizedBox.square(dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2,
                                          semanticsLabel: '연결 중'))
                                    : Text(_signUp ? '가입하기' : '로그인'),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _busy ? null : () => setState(() {
                                    _error = null;
                                    _signUp = !_signUp;
                                  }),
                                  child: Text(_signUp ? '이미 계정이 있나요? 로그인' : '처음 오셨나요? 가입하기',
                                    textAlign: TextAlign.center),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('오늘은 조금만 해도 괜찮아.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF294536), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF5F7EF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD5DFCE)),
    ),
  );
}
