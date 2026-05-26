# Sync offline-first

> Cómo COMAND-IA mantiene "cero pérdida de pedidos durante desconexión mientras la app permanezca abierta" (RNF-REL-002). Decisión: [ADR-0008](../architecture/decisions/0008-sync-offline-first-fifo-lww.md). Invariante: ACID-7.

## Flujo de 6 pasos

```
1. UI llama OrderRepository.create(order)
       │
       ▼
2. Repo persiste en Drift (local-cache) → emite stream → UI re-renderiza con dato local
       │
       ▼
3. Repo encola en pending_op { op_type: 'create_order', payload: {...}, created_at, attempts: 0 }
       │
       ▼
4. SyncService (Riverpod, background) escucha conectividad
   - Conectado → toma ops FIFO de pending_op → llama supabase-dart SDK
       │
       ▼
5. Si Supabase falla:
   - attempts++ en pending_op
   - Backoff exponencial: 2^attempts segundos (máx. 5 min)
   - Si attempts > 10 → notifica owner via estado observable
       │
       ▼
6. Si Supabase OK:
   - Actualiza la fila remota; server retorna updated_at timestamp
   - LWW: si el servidor tiene updated_at > local → local adopta el valor del servidor
   - Borra la op de pending_op
```

## Resolución de conflictos: LWW

El campo `updated_at` se actualiza en Postgres vía trigger `set_updated_at()`. **El cliente nunca genera timestamps de `updated_at`; los recibe del servidor.** En caso de conflicto (misma fila editada offline en dos dispositivos), gana la escritura con `updated_at` más reciente en el servidor.

**Garantía:** pérdida cero en desconexión mientras la app permanezca activa. La cola FIFO `pending_op` se persiste en Drift (SQLite/IndexedDB) y sobrevive reinicios de la app.

## Estructura de `pending_op` (local-only)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | int auto | Orden de inserción local. |
| `venue_id` | uuid | Para filtrar por venue al leer la cola. |
| `op_type` | text | `create_order` \| `update_order_item` \| `close_order` \| `update_order_status` \| ... |
| `payload` | jsonb | Cuerpo de la operación serializado. |
| `created_at` | timestamptz | Timestamp local (no se usa para LWW; solo para ordenar la cola). |
| `attempts` | int | Contador de reintentos; trigger del backoff. |

`pending_op` **no existe en el schema Postgres**. Solo vive en Drift. Verificado por test pgTAP (`supabase/tests/`).

## Backoff y notificación

- Backoff exponencial: `2^attempts` segundos, con cap en 5 min.
- Si `attempts > 10` → `SyncService` actualiza un provider observable que la UI escucha; owner ve un banner de "sync degradada" con detalle.
- El estado `attempts > 10` no detiene la cola: se sigue intentando con el backoff cap, pero se le avisa al owner para que verifique conectividad o credenciales.

## Casos límite cubiertos

| Caso | Comportamiento |
|---|---|
| Garzón crea pedido offline. | Persiste en Drift; UI confirma OK; encola en `pending_op`. CA-003. |
| Red vuelve. | `SyncService` toma op FIFO; envía a Supabase; KDS recibe en ≤2s. CA-004. |
| Garzón cierra app antes de sync. | Al reabrir, `SyncService` retoma `pending_op` desde Drift y reintenta. RNF-REL-002. |
| Red intermitente con fallos sucesivos. | Backoff exponencial; tras 10 fallos, notifica al owner sin detener la cola. |
| Otra sesión modifica la misma fila. | LWW: gana la escritura con `updated_at` más reciente del servidor. |
| Storage local borrado (cache flush, modo privado). | Las ops pendientes se pierden. **Caso documentado y excepcional.** |

## Garantías

- **Causalidad por dispositivo:** las ops del mismo dispositivo se procesan en orden de `created_at`. ACID-7.
- **Timestamp de servidor como fuente de verdad temporal:** evita drift de relojes del cliente.
- **No bloqueo de UI:** el sync corre en isolate/background; la UI responde durante la operación. RNF-PERF-002.

## Lo que LWW pierde

LWW puede perder la escritura más antigua en caso de **edición concurrente desde dos dispositivos sobre la misma fila**. Para el caso de uso real (un garzón por mesa, no edición simultánea del mismo pedido), este riesgo es aceptable y está documentado en el ADR.

Si en el futuro se necesita edición concurrente real (ej: garzón + supervisor editando el mismo pedido), la mitigación natural es CRDT por campo o locks pesimistas en Postgres — pero queda fuera de scope MVP.

## Referencias

- [ADR-0008](../architecture/decisions/0008-sync-offline-first-fifo-lww.md) — Sync FIFO + LWW.
- [SRS § 4.4 Reliability](../requirements/srs.md) — RNF-REL-001, RNF-REL-002.
- [SRS § 5](../requirements/srs.md) — CA-003, CA-004, CA-005.
- [architecture/c4-container.md](../architecture/c4-container.md) — contenedores y capas internas, incluyendo el `SyncService` en la capa de datos.
