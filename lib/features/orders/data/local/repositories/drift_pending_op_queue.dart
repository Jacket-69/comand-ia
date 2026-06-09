import 'dart:convert';

import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/repositories/pending_op_queue.dart';
import 'package:drift/drift.dart';

/// Implementación Drift de [PendingOpQueue].
///
/// ACID-7: FIFO estricto por [venueId] garantizado por el ordenamiento
/// ascendente del id autoincremental (orden de inserción). Solo las ops
/// con status 'pending' participan del drenaje; las 'dead' (error permanente)
/// quedan fuera de peek/head pero se conservan para diagnóstico (COMA-008).
class DriftPendingOpQueue implements PendingOpQueue {
  const DriftPendingOpQueue(this._db);

  final AppDatabase _db;

  static final _pendingStatus = PendingOpStatus.pending.toDb();

  @override
  Future<int> enqueue({
    required String venueId,
    required PendingOpType opType,
    required Map<String, dynamic> payload,
  }) {
    final companion = PendingOpsCompanion.insert(
      venueId: venueId,
      opType: opType.toDb(),
      payload: jsonEncode(payload),
    );
    return _db.into(_db.pendingOps).insert(companion);
  }

  @override
  Future<List<PendingOp>> peek(String venueId) async {
    final rows =
        await (_db.select(_db.pendingOps)
              ..where(
                (t) =>
                    t.venueId.equals(venueId) & t.status.equals(_pendingStatus),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return rows.map(pendingOpFromRow).toList();
  }

  @override
  Future<PendingOp?> head(String venueId) async {
    final rows =
        await (_db.select(_db.pendingOps)
              ..where(
                (t) =>
                    t.venueId.equals(venueId) & t.status.equals(_pendingStatus),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .get();

    if (rows.isEmpty) return null;
    return pendingOpFromRow(rows.first);
  }

  @override
  Future<void> markAttempt(int id, {String? error}) async {
    // Incrementa attempts con SQL directo para evitar race conditions
    if (error == null) {
      await _db.customUpdate(
        'UPDATE pending_ops SET attempts = attempts + 1 WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {_db.pendingOps},
      );
    } else {
      await _db.customUpdate(
        'UPDATE pending_ops SET attempts = attempts + 1, last_error = ? '
        'WHERE id = ?',
        variables: [Variable.withString(error), Variable.withInt(id)],
        updates: {_db.pendingOps},
      );
    }
  }

  @override
  Future<void> markDead(int id, String error) async {
    await (_db.update(_db.pendingOps)..where((t) => t.id.equals(id))).write(
      PendingOpsCompanion(
        status: Value(PendingOpStatus.dead.toDb()),
        lastError: Value(error),
      ),
    );
  }

  @override
  Future<void> remove(int id) async {
    await (_db.delete(_db.pendingOps)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<String>> venuesWithPending() async {
    final venueId = _db.pendingOps.venueId;
    final query =
        _db.selectOnly(_db.pendingOps, distinct: true)
          ..addColumns([venueId])
          ..where(_db.pendingOps.status.equals(_pendingStatus));
    final rows = await query.get();
    return rows.map((row) => row.read(venueId)!).toList();
  }

  @override
  Stream<int> watchPendingCount() {
    final count = _db.pendingOps.id.count();
    final query =
        _db.selectOnly(_db.pendingOps)
          ..addColumns([count])
          ..where(_db.pendingOps.status.equals(_pendingStatus));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }
}
