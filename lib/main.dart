import 'package:comand_ia/app/app.dart';
import 'package:comand_ia/core/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solo con configuración explícita (--dart-define SUPABASE_ANON_KEY):
  // sin ella la app corre 100 % local y el SyncService queda dormido.
  if (Env.hasSupabaseConfig) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: App()));
}
