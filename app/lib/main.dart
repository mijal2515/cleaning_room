import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.check();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  runApp(const ProviderScope(child: CleaningCoachApp()));
}
