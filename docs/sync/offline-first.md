# Sync offline-first

> Cómo COMAND-IA mantiene "cero pérdida de pedidos durante desconexión mientras la app permanezca abierta" (RNF-REL-002). Decisiones: [ADR-0008](../architecture/decisions/0008-sync-offline-first-fifo-lww.md) (FIFO + LWW) y [ADR-0013](../architecture/decisions/0013-drenaje-sync-idempotencia-dead-letter.md) (drenaje, idempotencia, dead-letter). Invariante: ACID-7.

## Flujo de 6 pasos

```
1. UI llama OrderRepository.create(order)
       │
       ▼
2. Repo persiste en Drift (local-cache) → emite stream → UI re-renderiza con dato local
       │
       ▼
3. Controller encola en pending_op { op_type, payload, created_at, attempts: 0 }
       │
       ▼
4. SyncService (Riverpod, background) drena FIFO por venue vía supabase-dart SDK.
   Disparadores: watch de Drift sobre pending_ops + cambios de sesión + timer de backoff.
   Solo drena con sesión utilizable (ensureReady: sesión + app_user visible).
       │
       ▼
5. Si Supabase falla:
   - Recuperable (red, 42501, PGRST*, desconocidos) → attempts++ y last_error;
     backoff exponencial 2^attempts segundos (máx. 5 min); el venue espera
     (head-of-line, ACID-7). Si attempts > 10 → estado degraded observable.
   - Permanente (23502/23503/23514/22P02/P0001) → la op pasa a status 'dead'
     con su diagnóstico y la cola sigue con la siguiente (dead-letter).
       │
       ▼
6. Si Supabase OK:
   - El server retorna updated_at; el espejo local lo adopta (LWW).
   - Borra la op de pending_op.
```

## Resolución de conflictos: LWW

El campo `updated_at` se actualiza en Postgres vía trigger `set_updated_at()`. **El cliente nunca genera timestamps de `updated_at`; los recibe del servidor.** En caso de conflicto (misma fila editada offline en dos dispositivos), gana la escritura con `updated_at` más reciente en el servidor.

**Garantía:** pérdida cero en desconexión mientras la app permanezca activa. La cola FIFO `pending_op` se persiste en Drift (SQLite/IndexedDB) y sobrevive reinicios de la app.

## Estructura de `pending_op` (local-only)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | int auto | Orden de inserción local = **orden FIFO de procesamiento** (ACID-7). |
| `venue_id` | uuid | Para filtrar por venue al leer la cola. |
| `op_type` | text | `create_order` \| `add_order_item` \| `update_order_item` \| `close_order` \| `update_order_status`. |
| `payload` | jsonb | Cuerpo de la operación serializado (ver formatos abajo). |
| `created_at` | timestamptz | Timestamp local (no se usa para LWW ni para ordenar; el orden lo da `id`). |
| `attempts` | int | Contador de reintentos; base del backoff. |
| `status` | text | `pending` (en cola) \| `dead` (descartada por error permanente, conservada para diagnóstico). |
| `last_error` | text? | Último error de sync registrado. |

`pending_op` **no existe en el schema Postgres**. Solo vive en Drift. Verificado por test pgTAP (`supabase/tests/`).

La implementación vive en `lib/features/orders/`: cola y reconciliador LWW en `data/local/repositories/`, gateway Supabase en `data/remote/`, y el `SyncService` con su política de backoff en `domain/sync/` (puro, sin imports de Flutter/Supabase/Drift).

## Formatos de payload por `op_type`

Campos que **jamás** viajan al servidor: `total_cents` (trigger `compute_order_total`, ACID-3) y `updated_at` (trigger `set_updated_at`, LWW). Todos los UUID se generan en cliente: el INSERT remoto usa upsert con `ignoreDuplicates`, de modo que un reintento tras éxito parcial es idempotente (ADR-0013).

| `op_type` | Payload | Acción remota |
|---|---|---|
| `create_order` | `{order_id, dining_table_id, venue_id, status, opened_by?, opened_at, items: [{order_item_id, menu_item_id, name_snapshot, price_cents_snapshot, quantity, status, comments?}]}` | upsert de `customer_order` + upsert masivo de `order_item`. |
| `add_order_item` | `{order_item_id, order_id, venue_id, menu_item_id, name_snapshot, price_cents_snapshot, quantity, status, comments?}` | upsert de un `order_item` (append mode). |
| `update_order_item` | `{order_item_id, order_id, venue_id, status}` | UPDATE de `status` del ítem (KDS: sent → preparing → ready). |
| `close_order` | `{order_id, venue_id, payment_method, tip_cents, closed_at}` | SELECT previo (si ya está `closed` → aplicada); si no, un solo UPDATE con `status='closed'` + `payment_method` + `tip_cents` (ACID-4 exige el cierre atómico). |
| `update_order_status` | `{order_id, venue_id, status}` | UPDATE de `status` del pedido. Definido pero hoy ningún productor lo encola (la derivación remota del estado entra con realtime). |

Los snapshots (`name_snapshot`, `price_cents_snapshot`) viajan tal como se capturaron al momento del pedido: desde la migración `0003_client_snapshots` el trigger remoto los respeta y solo los rellena desde `menu_item` cuando vienen vacíos (ACID-2 anclado a la toma del pedido, no al drenaje).

## Seed de dev

Mientras no exista el pull de menú/mesas desde Supabase (historia de realtime), el menú local se puebla mediante un seed idempotente de dev al arrancar la app:

- **Archivo:** `lib/features/orders/data/local/seed/dev_seed.dart`
- **Provider:** `devSeedProvider` (FutureProvider, idempotente: no re-siembra si ya hay categorías para el venue).
- **venueId seedado:** `venue-001-mock` (coincide con el mock de auth, definido en `MockAuthRepository`).
- **Contenido:** 20 mesas (ids `"1".."20"`), 6 categorías (Entradas, Almuerzos, Parrilladas, Bebidas, Postres, Café) y ~29 ítems con precios realistas en CLP (centavos, sin floats).
- **Activación:** `lib/app/app.dart` llama `ref.watch(devSeedProvider)` al arrancar. La pantalla de pedido (`OrderScreen`) también espera al seed antes de mostrar el menú.

Sin `SUPABASE_ANON_KEY` (dart-define) la app corre 100 % local: la cola se llena igual y el `SyncService` queda dormido. Con configuración y sesión real, el drenaje corre solo. El seed se reemplazará por la sincronización de catálogo cuando entre el pull remoto.

## KDS local y drenaje

El KDS de cocina opera contra Drift, sin depender de la red. En un solo dispositivo, el loop **toma → cocina → listo → pago** funciona completo offline:

- **Lectura reactiva:** la pantalla de cocina observa `watchActiveOrders` (pedidos en `sent`/`preparing`/`ready`) y los ítems de cada pedido con `watchItems`. El grid de mesas observa `watchNonClosedOrders` para reflejar en vivo el estado de cada mesa (libre / con pedido / listo).
- **Avance de ítem:** marcar un ítem (`sent → preparing → ready`) escribe el estado local y **re-deriva el estado del pedido**: todos los ítems no cancelados en `ready` → pedido `ready`; alguno en `preparing`/`ready` → pedido `preparing`; todos en `sent` → pedido `sent`. La derivación nunca degrada un pedido `closed` ni `cancelled` (ACID-4).
- **Encolado y drenaje:** cada avance encola `update_order_item` en `pending_op`; el `SyncService` (COMA-008) drena la cola hacia Supabase en orden FIFO por venue.

Lo que **no** está todavía: la suscripción Realtime para que una tablet de cocina *aparte* vea los pedidos en vivo (canal `venue_<uuid>_orders`), y con ella la re-derivación remota del estado del pedido. Es la siguiente historia del milestone Sprint 3.

## Backoff, clasificación de errores y notificación

- Backoff exponencial: `2^attempts` segundos, con cap en 5 min (`SyncBackoffPolicy`).
- Clasificación (gateway, según la tabla de [contracts.md](../api/contracts.md)):
  - **Recuperable** → `attempts++` + `last_error` + backoff: red caída, timeouts, `42501` (RLS: la sesión/membresía puede repararse), `PGRST*` y cualquier código desconocido. *Ante la duda, recuperable: jamás se descartan datos por un error no identificado.*
  - **Permanente** → dead-letter (`status = 'dead'` + `last_error`), la cola sigue: `23502` NOT NULL, `23503` FK, `23514` CHECK, `22P02` formato, `P0001` invariante de trigger (p. ej. pedido cerrado, ACID-4).
- Si `attempts > 10` → `SyncService` emite `SyncStatus(degraded)` por su stream observable (`syncStatusProvider`); el owner ve un banner de "sync degradada" con detalle.
- El estado degradado no detiene la cola: se sigue intentando con el backoff cap, pero se le avisa al owner para que verifique conectividad o credenciales.
- Sin sesión utilizable (`ensureReady()` falso) no se drena ni se consumen `attempts`: se reintenta al cap del backoff o antes si cambia la sesión o entra una op nueva.

## Casos límite cubiertos

| Caso | Comportamiento |
|---|---|
| Garzón crea pedido offline. | Persiste en Drift; UI confirma OK; encola en `pending_op`. CA-003. |
| Red vuelve. | El reintento del backoff (o una op nueva) drena FIFO; KDS recibe en ≤2s. CA-004. |
| Garzón cierra app antes de sync. | Al reabrir, `SyncService` retoma `pending_op` desde Drift y reintenta. RNF-REL-002. |
| Red intermitente con fallos sucesivos. | Backoff exponencial; tras 10 fallos, notifica al owner sin detener la cola. |
| Op aplicada pero la app murió antes de borrarla. | Reintento idempotente: upsert `ignoreDuplicates` / cierre verifica estado remoto → éxito sin duplicar. |
| El servidor rechaza la op en forma permanente (FK, pedido cerrado). | Dead-letter: `status='dead'` + `last_error`; la cola del venue sigue. |
| Otra sesión modifica la misma fila. | LWW: gana la escritura con `updated_at` más reciente del servidor. |
| Storage local borrado (cache flush, modo privado). | Las ops pendientes se pierden. **Caso documentado y excepcional.** |

## Garantías

- **Causalidad por dispositivo:** las ops del mismo dispositivo se procesan en orden de inserción (`id` autoincremental, por venue). ACID-7.
- **Timestamp de servidor como fuente de verdad temporal:** evita drift de relojes del cliente. Los timestamps de negocio (`opened_at`, `closed_at`) se normalizan a UTC antes de enviarse.
- **No bloqueo de UI:** el sync corre en background fuera del árbol de widgets; la UI responde durante la operación. RNF-PERF-002.

## Lo que LWW pierde

LWW puede perder la escritura más antigua en caso de **edición concurrente desde dos dispositivos sobre la misma fila**. Para el caso de uso real (un garzón por mesa, no edición simultánea del mismo pedido), este riesgo es aceptable y está documentado en el ADR.

Si en el futuro se necesita edición concurrente real (ej: garzón + supervisor editando el mismo pedido), la mitigación natural es CRDT por campo o locks pesimistas en Postgres — pero queda fuera de scope MVP.

## Referencias

- [ADR-0008](../architecture/decisions/0008-sync-offline-first-fifo-lww.md) — Sync FIFO + LWW.
- [ADR-0013](../architecture/decisions/0013-drenaje-sync-idempotencia-dead-letter.md) — Drenaje: idempotencia, dead-letter, snapshots del cliente.
- [SRS § 4.4 Reliability](../requirements/srs.md) — RNF-REL-001, RNF-REL-002.
- [SRS § 5](../requirements/srs.md) — CA-003, CA-004, CA-005.
- [architecture/c4-container.md](../architecture/c4-container.md) — contenedores y capas internas, incluyendo el `SyncService` en la capa de datos.
