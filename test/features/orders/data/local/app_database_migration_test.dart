import 'dart:io';

import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresión de las migraciones Drift v1→v2→v3→v4 (columnas aditivas).
///
/// La primera versión de la migración v1→v2 borraba y recreaba las seis tablas,
/// lo que destruía pedidos abiertos y la cola FIFO de sincronización (viola
/// ACID-7). La migración correcta es aditiva: solo agrega la columna a
/// `menu_items` (v2), a `customer_orders` (v3) o a `pending_ops` (v4).
/// Este test fija ese contrato sobre una base persistente en disco para poder
/// cerrar y reabrir disparando el `onUpgrade` real.
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

  test('migración v1→v4 agrega description, tip_cents y status/last_error '
      'sin destruir pedidos ni la cola FIFO', () async {
    // ── Arrange: simula una base en estado v1 ──────────────────────────────
    // Se abre la base v4 (actual), se siembran un pedido y una pending_op, y
    // luego se "rebobina" a v1 quitando las columnas nuevas (description de
    // menu_items, tip_cents de customer_orders, status/last_error de
    // pending_ops) y bajando user_version. Así el siguiente open ve una base
    // v1 real que debe sobrevivir sin pérdida.
    final v4 = AppDatabase.forTesting(NativeDatabase(dbFile));

    await v4
        .into(v4.customerOrders)
        .insert(
          CustomerOrdersCompanion.insert(
            id: 'order-1',
            venueId: 'venue-A',
            diningTableId: 'table-1',
            openedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await v4
        .into(v4.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            venueId: 'venue-A',
            opType: 'create_order',
            payload: '{"orderId":"order-1"}',
          ),
        );

    // Estado v1: sin las columnas agregadas en v2/v3/v4; con una fila de
    // menú preexistente.
    await v4.customStatement('ALTER TABLE menu_items DROP COLUMN description');
    await v4.customStatement(
      'ALTER TABLE customer_orders DROP COLUMN tip_cents',
    );
    await v4.customStatement('ALTER TABLE pending_ops DROP COLUMN status');
    await v4.customStatement('ALTER TABLE pending_ops DROP COLUMN last_error');
    await v4.customStatement(
      "INSERT INTO menu_items (id, venue_id, category_id, name, price_cents) "
      "VALUES ('item-1', 'venue-A', 'cat-1', 'Pizza', 7900)",
    );
    await v4.customStatement('PRAGMA user_version = 1');
    await v4.close();

    // ── Act: reabrir dispara onUpgrade(1 → 4) ─────────────────────────────
    final migrated = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(migrated.close);

    // ── Assert: los datos sobreviven a las tres migraciones ────────────────
    final orders = await migrated.select(migrated.customerOrders).get();
    expect(orders, hasLength(1), reason: 'el pedido no debe borrarse');
    expect(orders.single.id, 'order-1');
    // tip_cents existe y la fila preexistente toma el default 0.
    expect(orders.single.tipCents, 0);

    final ops = await migrated.select(migrated.pendingOps).get();
    expect(ops, hasLength(1), reason: 'la cola FIFO no debe borrarse');
    expect(ops.single.opType, 'create_order');
    // status/last_error existen; la op preexistente queda 'pending' y
    // sigue participando del drenaje FIFO (ACID-7).
    expect(ops.single.status, 'pending');
    expect(ops.single.lastError, isNull);

    // La columna description existe y la fila preexistente toma el default vacío.
    final items = await migrated.select(migrated.menuItems).get();
    expect(items, hasLength(1));
    expect(items.single.description, '');
  });
}
