import 'dart:convert';

import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:comand_ia/features/orders/domain/repositories/pending_op_queue.dart';
import 'package:drift/drift.dart';

/// Implementación Drift de [PendingOpQueue].
///
/// ACID-7: FIFO estricto por [venueId] garantizado por el ordenamiento
/// ascendente del id autoincremental (orden de inserción).
class DriftPendingOpQueue implements PendingOpQueue {
  const DriftPendingOpQueue(this._db);

  final AppDatabase _db;

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
              ..where((t) => t.venueId.equals(venueId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return rows.map(pendingOpFromRow).toList();
  }

  @override
  Future<PendingOp?> head(String venueId) async {
    final rows =
        await (_db.select(_db.pendingOps)
              ..where((t) => t.venueId.equals(venueId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .get();

    if (rows.isEmpty) return null;
    return pendingOpFromRow(rows.first);
  }

  @override
  Future<void> markAttempt(int id) async {
    // Incrementa attempts con SQL directo para evitar race conditions
    await _db.customUpdate(
      'UPDATE pending_ops SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {_db.pendingOps},
    );
  }

  @override
  Future<void> remove(int id) async {
    await (_db.delete(_db.pendingOps)..where((t) => t.id.equals(id))).go();
  }
}
