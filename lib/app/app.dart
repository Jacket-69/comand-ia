import 'package:comand_ia/app/router.dart';
import 'package:comand_ia/app/theme.dart';
import 'package:comand_ia/features/orders/presentation/providers/seed_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget raíz de COMAND-IA.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Dispara el seed de dev en background al arrancar la app.
    // La pantalla de pedido espera este future antes de mostrar el menú.
    ref.watch(devSeedProvider);

    return MaterialApp.router(
      title: 'COMAND-IA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
