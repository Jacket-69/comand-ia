import 'package:comand_ia/core/env.dart';
import 'package:comand_ia/features/orders/data/local/repositories/drift_sync_local_reconciler.dart';
import 'package:comand_ia/features/orders/data/remote/supabase_order_remote_data_source.dart';
import 'package:comand_ia/features/orders/data/remote/supabase_order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_service.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_status.dart';
import 'package:comand_ia/features/orders/presentation/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gateway remoto de sync, o null si Supabase no está configurado.
///
/// Sin `SUPABASE_ANON_KEY` (dart-define) la app es 100 % local: la cola
/// FIFO se llena igual (ACID-7) y se drenará cuando exista configuración.
final orderRemoteGatewayProvider = Provider<OrderRemoteGateway?>((ref) {
  if (!Env.hasSupabaseConfig) return null;
  return SupabaseOrderRemoteGateway(
    SupabaseOrderRemoteDataSource(Supabase.instance.client),
  );
});

/// SyncService de fondo (COMA-008), o null si no hay backend configurado.
///
/// Se arranca con `ref.watch(syncServiceProvider)` desde [App] — mismo patrón
/// fire-and-watch que `devSeedProvider`. Vive fuera del árbol de widgets:
/// la UI nunca se bloquea durante la sincronización (RNF-PERF-002).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final gateway = ref.watch(orderRemoteGatewayProvider);
  if (gateway == null) return null;

  final service = SyncService(
    queue: ref.watch(pendingOpQueueProvider),
    gateway: gateway,
    reconciler: DriftSyncLocalReconciler(ref.watch(appDatabaseProvider)),
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

/// Estado observable del sync para la UI (banner "sync degradada" del owner).
///
/// Sin backend configurado emite el estado inicial (idle) y nada más.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return Stream.value(SyncStatus.initial);
  return service.statusStream;
});
