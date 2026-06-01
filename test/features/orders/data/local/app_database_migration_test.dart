import 'dart:io';

import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresión de la migración Drift v1 → v2 (columna `menu_items.description`).
///
/// La primera versión de esta migración borraba y recreaba las seis tablas,
/// lo que destruía pedidos abiertos y la cola FIFO de sincronización (viola
/// ACID-7). La migración correcta es aditiva: solo agrega la columna a
/// `menu_items`. Este test fija ese contrato sobre una base persistente en
/// disco para poder cerrar y reabrir disparando el `onUpgrade` real.
void main() {
  late Directory tmpDir;
  late File dbFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('comandia_migration');
    dbFile = File('${tmpDir.path}/comand_ia.sqlite');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'migración v1→v2 agrega description sin destruir pedidos ni la cola FIFO',
    () async {
      // ── Arrange: simula una base en estado v1 ──────────────────────────────
      // Se abre la base v2, se siembran un pedido y una pending_op, y luego se
      // "rebobina" a v1 quitando la columna nueva y bajando user_version. Así
      // el siguiente open ve una base v1 con datos reales que deben sobrevivir.
      final v2 = AppDatabase.forTesting(NativeDatabase(dbFile));

      await v2
          .into(v2.customerOrders)
          .insert(
            CustomerOrdersCompanion.insert(
              id: 'order-1',
              venueId: 'venue-A',
              diningTableId: 'table-1',
              openedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await v2
          .into(v2.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              venueId: 'venue-A',
              opType: 'create_order',
              payload: '{"orderId":"order-1"}',
            ),
          );

      // Estado v1: sin columna description y con una fila de menú preexistente.
      await v2.customStatement(
        'ALTER TABLE menu_items DROP COLUMN description',
      );
      await v2.customStatement(
        "INSERT INTO menu_items (id, venue_id, category_id, name, price_cents) "
        "VALUES ('item-1', 'venue-A', 'cat-1', 'Pizza', 7900)",
      );
      await v2.customStatement('PRAGMA user_version = 1');
      await v2.close();

      // ── Act: reabrir dispara onUpgrade(1, 2) ───────────────────────────────
      final migrated = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(migrated.close);

      // ── Assert: los datos sobreviven a la migración ────────────────────────
      final orders = await migrated.select(migrated.customerOrders).get();
      expect(orders, hasLength(1), reason: 'el pedido no debe borrarse');
      expect(orders.single.id, 'order-1');

      final ops = await migrated.select(migrated.pendingOps).get();
      expect(ops, hasLength(1), reason: 'la cola FIFO no debe borrarse');
      expect(ops.single.opType, 'create_order');

      // La columna nueva existe y la fila preexistente toma el default vacío.
      final items = await migrated.select(migrated.menuItems).get();
      expect(items, hasLength(1));
      expect(items.single.description, '');
    },
  );
}
