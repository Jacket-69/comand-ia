import 'dart:async';
import 'dart:convert';

import 'package:comand_ia/features/orders/data/remote/supabase_order_remote_gateway.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/sync/order_remote_data_source.dart';
import 'package:comand_ia/features/orders/domain/sync/sync_apply_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data source falso: el test programa qué retorna cada I/O y registra las
/// llamadas, para ejercitar la lógica de [SupabaseOrderRemoteGateway.apply]
/// sin un SupabaseClient real ni mockear la cadena PostgREST.
class _FakeDataSource implements OrderRemoteDataSource {
  @override
  String? currentUserId = 'uid-1';
  @override
  bool hasActiveSession = true;

  final _sessionController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get sessionActiveChanges => _sessionController.stream;

  bool appUserVisible = true;
  Object? appUserError;
  @override
  Future<bool> isAppUserVisible(String uid) async {
    if (appUserError != null) throw appUserError!;
    return appUserVisible;
  }

  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  Object? upsertError;
  @override
  Future<void> upsertIgnoreDuplicates(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (upsertError != null) throw upsertError!;
    upserts.add((table: table, rows: rows));
  }

  final updates = <({String table, String id, Map<String, dynamic> values})>[];
  Object? updateError;
  List<Map<String, dynamic>> updateResult = const [];
  @override
  Future<List<Map<String, dynamic>>> updateByIdReturningTimestamps(
    String table,
    String id,
    Map<String, dynamic> values,
  ) async {
    if (updateError != null) throw updateError!;
    updates.add((table: table, id: id, values: values));
    return updateResult;
  }

  Map<String, dynamic>? maybeSingleResult;
  @override
  Future<Map<String, dynamic>?> selectMaybeSingle(
    String table,
    String columns,
    String filterColumn,
    String filterValue,
  ) async {
    return maybeSingleResult;
  }

  /// Filas `{id, updated_at}` que devuelve selectTimestamps, por tabla.
  Map<String, List<Map<String, dynamic>>> timestampsByTable = const {};
  @override
  Future<List<Map<String, dynamic>>> selectTimestamps(
    String table,
    String filterColumn,
    String filterValue,
  ) async {
    return timestampsByTable[table] ?? const [];
  }

  Future<void> close() => _sessionController.close();
}

PendingOp _op(PendingOpType type, Map<String, dynamic> payload) => PendingOp(
  id: 1,
  venueId: 'venue-1',
  opType: type,
  payload: jsonEncode(payload),
  createdAt: DateTime.utc(2026, 6, 9),
  attempts: 0,
);

void main() {
  group('orderInsertRow (create_order)', () {
    final payload = {
      'order_id': 'order-1',
      'dining_table_id': 'table-1',
      'venue_id': 'venue-1',
      'status': 'sent',
      'opened_by': 'user-1',
      'opened_at': '2026-06-09T14:30:00.000',
      'items': const <Object>[],
    };

    test('mapea id, venue, mesa, status y opened_by/opened_at', () {
      final row = SupabaseOrderRemoteGateway.orderInsertRow(payload);

      expect(row['id'], 'order-1');
      expect(row['venue_id'], 'venue-1');
      expect(row['dining_table_id'], 'table-1');
      expect(row['status'], 'sent');
      expect(row['opened_by'], 'user-1');
    });

    test(
      'jamás incluye total_cents ni updated_at (server-managed, ACID-3)',
      () {
        final row = SupabaseOrderRemoteGateway.orderInsertRow({
          ...payload,
          'total_cents': 9999,
        });

        expect(row.containsKey('total_cents'), isFalse);
        expect(row.containsKey('updated_at'), isFalse);
      },
    );

    test('omite opened_by nulo (pedido sin garzón identificado)', () {
      final row = SupabaseOrderRemoteGateway.orderInsertRow({
        ...payload,
        'opened_by': null,
      });

      expect(row.containsKey('opened_by'), isFalse);
    });
  });

  group('itemInsertRows (create_order)', () {
    test('mapea cada ítem con su UUID y snapshots del cliente (ACID-2)', () {
      final rows = SupabaseOrderRemoteGateway.itemInsertRows({
        'order_id': 'order-1',
        'venue_id': 'venue-1',
        'items': [
          {
            'order_item_id': 'item-1',
            'menu_item_id': 'menu-1',
            'name_snapshot': 'Lomo (promo)',
            'price_cents_snapshot': 1500,
            'quantity': 2,
            'status': 'sent',
            'comments': 'sin cebolla',
          },
        ],
      });

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['id'], 'item-1');
      expect(row['order_id'], 'order-1');
      expect(row['venue_id'], 'venue-1');
      expect(row['name_snapshot'], 'Lomo (promo)');
      expect(row['price_cents_snapshot'], 1500);
      expect(row['quantity'], 2);
      expect(row['comments'], 'sin cebolla');
    });

    test('payload sin items retorna lista vacía', () {
      final rows = SupabaseOrderRemoteGateway.itemInsertRows({
        'order_id': 'order-1',
        'venue_id': 'venue-1',
      });
      expect(rows, isEmpty);
    });
  });

  group('singleItemInsertRow (add_order_item)', () {
    test('mapea el ítem plano con su UUID (idempotencia)', () {
      final row = SupabaseOrderRemoteGateway.singleItemInsertRow({
        'order_item_id': 'item-9',
        'order_id': 'order-1',
        'venue_id': 'venue-1',
        'menu_item_id': 'menu-2',
        'name_snapshot': 'Café',
        'price_cents_snapshot': 250000,
        'quantity': 1,
        'status': 'sent',
      });

      expect(row['id'], 'item-9');
      expect(row['menu_item_id'], 'menu-2');
      expect(row['price_cents_snapshot'], 250000);
      expect(row.containsKey('comments'), isFalse);
    });
  });

  group('utcIso', () {
    test('normaliza timestamps locales a UTC para timestamptz', () {
      final result = SupabaseOrderRemoteGateway.utcIso(
        '2026-06-09T14:30:00.000',
      );
      expect(result, endsWith('Z'));
      expect(DateTime.parse(result).isUtc, isTrue);
    });
  });

  group('classifyError', () {
    test('errores de datos son permanentes (dead-letter)', () {
      const codes = ['23502', '23503', '23514', '22P02', 'P0001'];
      for (final code in codes) {
        final result = SupabaseOrderRemoteGateway.classifyError(
          PostgrestException(message: 'boom', code: code),
        );
        expect(result, isA<SyncRejected>(), reason: 'código $code');
      }
    });

    test('42501 (RLS) es recuperable: la sesión puede repararse', () {
      final result = SupabaseOrderRemoteGateway.classifyError(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      expect(result, isA<SyncUnavailable>());
    });

    test('AuthException es recuperable', () {
      final result = SupabaseOrderRemoteGateway.classifyError(
        const AuthException('JWT expired'),
      );
      expect(result, isA<SyncUnavailable>());
    });

    test('códigos desconocidos son recuperables: jamás descartar datos '
        'por un error no identificado', () {
      final unknownPg = SupabaseOrderRemoteGateway.classifyError(
        const PostgrestException(message: 'transient', code: 'PGRST301'),
      );
      expect(unknownPg, isA<SyncUnavailable>());

      final transport = SupabaseOrderRemoteGateway.classifyError(
        Exception('SocketException: red caída'),
      );
      expect(transport, isA<SyncUnavailable>());
    });
  });

  group('apply — lógica de drenaje sobre el data source', () {
    late _FakeDataSource ds;
    late SupabaseOrderRemoteGateway gateway;

    setUp(() {
      ds = _FakeDataSource();
      gateway = SupabaseOrderRemoteGateway(ds);
    });

    tearDown(() => ds.close());

    test(
      'payload corrupto es permanente (no se reintenta un JSON inválido)',
      () async {
        final op = PendingOp(
          id: 1,
          venueId: 'venue-1',
          opType: PendingOpType.createOrder,
          payload: 'esto no es json {',
          createdAt: DateTime.utc(2026, 6, 9),
          attempts: 0,
        );

        expect(await gateway.apply(op), isA<SyncRejected>());
      },
    );

    group('create_order', () {
      test(
        'upserta pedido + ítems y adopta los timestamps del server (LWW)',
        () async {
          ds.timestampsByTable = {
            'customer_order': [
              {'id': 'order-1', 'updated_at': '2026-06-09T12:00:00Z'},
            ],
            'order_item': [
              {'id': 'item-1', 'updated_at': '2026-06-09T12:00:00Z'},
            ],
          };

          final result = await gateway.apply(
            _op(PendingOpType.createOrder, {
              'order_id': 'order-1',
              'venue_id': 'venue-1',
              'dining_table_id': 'table-1',
              'items': [
                {
                  'order_item_id': 'item-1',
                  'menu_item_id': 'menu-1',
                  'name_snapshot': 'Lomo',
                  'price_cents_snapshot': 1500,
                },
              ],
            }),
          );

          expect(result, isA<SyncApplied>());
          final applied = result as SyncApplied;
          expect(applied.orderTimestamps.containsKey('order-1'), isTrue);
          expect(applied.itemTimestamps.containsKey('item-1'), isTrue);
          // Pedido e ítems se upsertearon (idempotencia por UUID de cliente).
          expect(ds.upserts.map((u) => u.table), [
            'customer_order',
            'order_item',
          ]);
        },
      );

      test(
        'jamás upsertea total_cents aunque venga en el payload (ACID-3)',
        () async {
          ds.timestampsByTable = {
            'customer_order': [
              {'id': 'order-1', 'updated_at': '2026-06-09T12:00:00Z'},
            ],
          };

          await gateway.apply(
            _op(PendingOpType.createOrder, {
              'order_id': 'order-1',
              'venue_id': 'venue-1',
              'dining_table_id': 'table-1',
              'total_cents': 99999,
              'updated_at': '2020-01-01T00:00:00Z',
              'items': const <Object>[],
            }),
          );

          final orderRow = ds.upserts.first.rows.single;
          expect(orderRow.containsKey('total_cents'), isFalse);
          expect(orderRow.containsKey('updated_at'), isFalse);
        },
      );

      test(
        'pedido no visible tras el insert es venue ajeno (permanente)',
        () async {
          ds.timestampsByTable = const {}; // customer_order no aparece.

          final result = await gateway.apply(
            _op(PendingOpType.createOrder, {
              'order_id': 'order-x',
              'venue_id': 'venue-ajeno',
              'dining_table_id': 'table-1',
              'items': const <Object>[],
            }),
          );

          expect(result, isA<SyncRejected>());
        },
      );
    });

    group('add_order_item', () {
      test(
        'reenvío idempotente: el upsert no-op igual retorna Applied',
        () async {
          ds.timestampsByTable = {
            'customer_order': [
              {'id': 'order-1', 'updated_at': '2026-06-09T12:00:00Z'},
            ],
            'order_item': [
              {'id': 'item-9', 'updated_at': '2026-06-09T12:00:00Z'},
            ],
          };

          final result = await gateway.apply(
            _op(PendingOpType.addOrderItem, {
              'order_item_id': 'item-9',
              'order_id': 'order-1',
              'venue_id': 'venue-1',
              'menu_item_id': 'menu-2',
              'name_snapshot': 'Café',
              'price_cents_snapshot': 2500,
            }),
          );

          expect(result, isA<SyncApplied>());
          expect(ds.upserts.single.table, 'order_item');
        },
      );
    });

    group('update_order_item', () {
      test(
        '0 filas afectadas → el ítem no existe en remoto (permanente)',
        () async {
          ds.updateResult = const [];

          final result = await gateway.apply(
            _op(PendingOpType.updateOrderItem, {
              'order_item_id': 'item-1',
              'order_id': 'order-1',
              'status': 'ready',
            }),
          );

          expect(result, isA<SyncRejected>());
        },
      );

      test('éxito adopta el updated_at del ítem actualizado', () async {
        ds.updateResult = [
          {'id': 'item-1', 'updated_at': '2026-06-09T12:30:00Z'},
        ];
        ds.timestampsByTable = {
          'customer_order': [
            {'id': 'order-1', 'updated_at': '2026-06-09T12:30:00Z'},
          ],
        };

        final result = await gateway.apply(
          _op(PendingOpType.updateOrderItem, {
            'order_item_id': 'item-1',
            'order_id': 'order-1',
            'status': 'ready',
          }),
        );

        expect(result, isA<SyncApplied>());
        expect((result as SyncApplied).itemTimestamps['item-1'], isNotNull);
      });
    });

    group('close_order', () {
      test('ya cerrado: idempotente (ACID-4) sin un segundo UPDATE', () async {
        ds.maybeSingleResult = {
          'id': 'order-1',
          'status': 'closed',
          'updated_at': '2026-06-09T12:00:00Z',
        };

        final result = await gateway.apply(
          _op(PendingOpType.closeOrder, {
            'order_id': 'order-1',
            'payment_method': 'cash',
            'tip_cents': 0,
          }),
        );

        expect(result, isA<SyncApplied>());
        // Terminal idempotente: no se intentó un UPDATE sobre el pedido cerrado.
        expect(ds.updates, isEmpty);
      });

      test('abierto: cierra con method + tip y adopta el timestamp', () async {
        ds.maybeSingleResult = {
          'id': 'order-1',
          'status': 'open',
          'updated_at': '2026-06-09T11:00:00Z',
        };
        ds.updateResult = [
          {'id': 'order-1', 'updated_at': '2026-06-09T12:00:00Z'},
        ];

        final result = await gateway.apply(
          _op(PendingOpType.closeOrder, {
            'order_id': 'order-1',
            'payment_method': 'card',
            'tip_cents': 1000,
          }),
        );

        expect(result, isA<SyncApplied>());
        final update = ds.updates.single;
        expect(update.values['status'], 'closed');
        expect(update.values['payment_method'], 'card');
        expect(update.values['tip_cents'], 1000);
      });

      test('pedido inexistente en remoto es permanente', () async {
        ds.maybeSingleResult = null;

        final result = await gateway.apply(
          _op(PendingOpType.closeOrder, {
            'order_id': 'order-1',
            'payment_method': 'cash',
            'tip_cents': 0,
          }),
        );

        expect(result, isA<SyncRejected>());
      });

      test('carrera (UPDATE afecta 0 filas) es recuperable', () async {
        ds.maybeSingleResult = {
          'id': 'order-1',
          'status': 'open',
          'updated_at': '2026-06-09T11:00:00Z',
        };
        ds.updateResult = const [];

        final result = await gateway.apply(
          _op(PendingOpType.closeOrder, {
            'order_id': 'order-1',
            'payment_method': 'cash',
            'tip_cents': 0,
          }),
        );

        expect(result, isA<SyncUnavailable>());
      });
    });

    group('clasificación de errores a través de apply', () {
      test('PostgrestException permanente (FK) → dead-letter', () async {
        ds.upsertError = const PostgrestException(
          message: 'FK violation',
          code: '23503',
        );

        final result = await gateway.apply(
          _op(PendingOpType.createOrder, {
            'order_id': 'order-1',
            'venue_id': 'venue-1',
            'dining_table_id': 'table-1',
            'items': const <Object>[],
          }),
        );

        expect(result, isA<SyncRejected>());
      });

      test('AuthException → recuperable', () async {
        ds.upsertError = const AuthException('JWT expired');

        final result = await gateway.apply(
          _op(PendingOpType.createOrder, {
            'order_id': 'order-1',
            'venue_id': 'venue-1',
            'dining_table_id': 'table-1',
            'items': const <Object>[],
          }),
        );

        expect(result, isA<SyncUnavailable>());
      });

      test(
        'error de transporte → recuperable (nunca descartar datos)',
        () async {
          ds.upsertError = Exception('SocketException: red caída');

          final result = await gateway.apply(
            _op(PendingOpType.createOrder, {
              'order_id': 'order-1',
              'venue_id': 'venue-1',
              'dining_table_id': 'table-1',
              'items': const <Object>[],
            }),
          );

          expect(result, isA<SyncUnavailable>());
        },
      );
    });
  });

  group('ensureReady', () {
    late _FakeDataSource ds;
    late SupabaseOrderRemoteGateway gateway;

    setUp(() {
      ds = _FakeDataSource();
      gateway = SupabaseOrderRemoteGateway(ds);
    });

    tearDown(() => ds.close());

    test('sin uid no está listo', () async {
      ds.currentUserId = null;
      expect(await gateway.ensureReady(), isFalse);
    });

    test('sin sesión activa no está listo', () async {
      ds.hasActiveSession = false;
      expect(await gateway.ensureReady(), isFalse);
    });

    test('con sesión y app_user visible está listo', () async {
      ds.appUserVisible = true;
      expect(await gateway.ensureReady(), isTrue);
    });

    test('app_user no visible (RLS) no está listo', () async {
      ds.appUserVisible = false;
      expect(await gateway.ensureReady(), isFalse);
    });

    test('error consultando app_user no está listo (no lanza)', () async {
      ds.appUserError = const PostgrestException(message: 'boom');
      expect(await gateway.ensureReady(), isFalse);
    });
  });
}
