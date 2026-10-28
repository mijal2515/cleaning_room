/// 빌드할 때 `--dart-define-from-file=env.json`으로 넣는 값.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static void check() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError('SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY가 없습니다. README의 "앱 실행" 참고.');
    }
  }
}
