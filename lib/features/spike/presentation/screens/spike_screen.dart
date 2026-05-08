import 'dart:convert';

import 'package:comand_ia/core/local/spike_db.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Pantalla del spike COMA-004 para validar Drift en Flutter web.
///
/// Permite ejecutar INSERT/SELECT/COUNT/DELETE sobre la tabla `pending_op`
/// de prueba y verificar manualmente que los datos sobreviven recargas y
/// distintos tabs (IndexedDB compartido). Se elimina cuando COMA-006 reemplace
/// el prototipo con la base local definitiva.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final SpikeDatabase _db = SpikeDatabase();
  final Uuid _uuid = const Uuid();

  List<SpikePendingOp> _ops = const [];
  int _count = 0;
  String _status = 'Sin operaciones aún.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, st) {
      setState(() => _status = 'Error: $e\n$st');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() {
    return _withBusy(() async {
      final ops = await _db.all();
      final count = await _db.count();
      setState(() {
        _ops = ops;
        _count = count;
        _status = 'SELECT OK · ${ops.length} filas leídas (count=$count).';
      });
    });
  }

  Future<void> _insertOne() {
    return _withBusy(() async {
      final id = await _db.enqueue(
        venueId: 'venue-spike',
        opType: 'create_order',
        payload: jsonEncode({
          'order_id': _uuid.v4(),
          'items': [
            {'name': 'Lomo a lo pobre', 'price_cents': 950000, 'qty': 1},
          ],
        }),
      );
      setState(() => _status = 'INSERT OK · id=$id.');
      await _refresh();
    });
  }

  Future<void> _insertMany() {
    return _withBusy(() async {
      for (var i = 0; i < 10; i++) {
        await _db.enqueue(
          venueId: 'venue-spike',
          opType: 'update_order_item',
          payload: jsonEncode({
            'i': i,
            'created_at_local': DateTime.now().toIso8601String(),
          }),
        );
      }
      setState(() => _status = 'INSERT x10 OK.');
      await _refresh();
    });
  }

  Future<void> _clear() {
    return _withBusy(() async {
      await _db.clearAll();
      setState(() => _status = 'DELETE * OK.');
      await _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COMA-004 · Spike Drift web'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filas en spike_pending_ops: $_count',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Text(
                      'Recarga la pestaña (Ctrl+R) para verificar persistencia '
                      'en IndexedDB. Abre otra pestaña en /spike para validar '
                      'multi-tab (debería ver el mismo conteo).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _insertOne,
                  icon: const Icon(Icons.add),
                  label: const Text('INSERT 1'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _insertMany,
                  icon: const Icon(Icons.dynamic_feed),
                  label: const Text('INSERT x10'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('DELETE *'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: _ops.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final op = _ops[i];
                  return ListTile(
                    dense: true,
                    title: Text('#${op.id} · ${op.opType}'),
                    subtitle: Text(
                      '${op.createdAt.toIso8601String()} · attempts=${op.attempts}\n${op.payload}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
