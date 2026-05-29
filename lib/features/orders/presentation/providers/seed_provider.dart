import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/orders/data/local/seed/dev_seed.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider de inicialización del seed de dev.
///
/// Expone un [AsyncValue<void>] que se resuelve cuando el seed terminó
/// (o si ya existían datos). La UI puede esperar en este future antes
/// de navegar a la pantalla de pedidos.
///
/// Idempotente: si ya hay datos, el seed no hace nada.
final devSeedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final menuRepo = ref.watch(menuLocalRepositoryProvider);
  try {
    await seedDevData(db, menuRepo);
  } catch (e, st) {
    AppLogger.error(
      'Error en dev seed',
      error: e,
      stackTrace: st,
      tag: 'DevSeed',
    );
    rethrow;
  }
});
