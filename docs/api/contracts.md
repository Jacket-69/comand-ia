# Contratos de API

> COMAND-IA es **BaaS-only**: no hay HTTP API artesanal. Esta es la fuente de verdad del contrato cliente↔Supabase. Reemplaza al `openapi.yaml` que la metodología pide para tipo Backend HTTP. Decisión: [ADR-0002](../architecture/decisions/0002-supabase-baas-backend.md).

## supabase-dart SDK (no REST artesanal)

El frontend usa el SDK `supabase-dart` directamente. **No hay capa REST artesanal entre la app y Supabase.**

```dart
// Ejemplo: insertar pedido
final response = await supabase
  .from('customer_order')
  .insert({
    'venue_id': venueId,
    'dining_table_id': tableId,
    'status': 'open',
    'opened_by': userId,
  })
  .select()
  .single();
```

El SDK aplica RLS automáticamente: la fila se inserta solo si `venue_id` coincide con el del usuario autenticado y la policy `venue_isolation` lo permite (ver [database/rls.md](../database/rls.md)).

## Tipos generados

Los tipos Dart se generan desde el schema real de Supabase:

```bash
supabase gen types --lang dart > lib/core/db_types.dart
```

Este archivo:

- **Es generado automáticamente. No se edita a mano.**
- Se regenera cada vez que cambia el schema (parte del flujo de cualquier PR que toca `supabase/migrations/`).
- Provee type-safety para `from(...).select()`, `insert()`, `update()`, `upsert()`, `delete()` con los tipos exactos del schema.

## Schema de tablas — fuente de verdad

El schema canónico vive en:

1. **`supabase/migrations/`** — SQL ejecutable. La migración `0001_init.sql` es el contrato base; las migraciones siguientes son cambios forward-only.
2. **[database/model.md](../database/model.md)** — descripción humana de tablas, columnas, invariantes y relaciones.
3. **`lib/core/db_types.dart`** — tipos Dart generados (espejo del SQL).

### Cambios recientes al schema

#### `0002_tip_cents` (COMA-014)

`customer_order` recibe una columna nueva:

| Columna | Tipo | Default | Constraint | Notas |
|---|---|---|---|---|
| `tip_cents` | `INT` | `0` | `CHECK (tip_cents >= 0)` | Propina decidida por el comensal en caja. **Separada de `total_cents`** (ACID-3): `total_cents` = solo ítems; `tip_cents` no entra al total. Se escribe al cerrar la cuenta. |

#### `0003_client_snapshots` (COMA-008)

Cambio de comportamiento del trigger `validate_order_item` ([ADR-0013](../architecture/decisions/0013-drenaje-sync-idempotencia-dead-letter.md)): en INSERT respeta `name_snapshot`/`price_cents_snapshot` provistos por el cliente (capturados offline al momento del pedido, ACID-2) y solo los rellena desde `menu_item` cuando `name_snapshot` viene vacío (`''`) o NULL — el sentinel del seed y de inserts server-side. En UPDATE siguen inmutables (restaurados desde OLD). Test pgTAP: `client_snapshots.sql`.

Si los tres divergen, la migración SQL gana. Hay que regenerar `db_types.dart` y actualizar `model.md` en el mismo PR.

### Escrituras del SyncService (COMA-008)

El drenaje de `pending_op` escribe directo sobre las tablas con la RLS del usuario autenticado (sin RPC de sync, coherente con BaaS-only):

- `customer_order`: upsert con `ignoreDuplicates` (`id` generado en cliente) para `create_order`; UPDATE para cierre (`status='closed'` + `payment_method` + `tip_cents` en una sola operación, ACID-4) y cambio de estado.
- `order_item`: upsert con `ignoreDuplicates` (`id` generado en cliente) para ítems nuevos; UPDATE de `status` para el avance del KDS.
- **Jamás envía** `total_cents` (trigger `compute_order_total`, ACID-3) ni `updated_at` (trigger `set_updated_at`, LWW).
- Requiere sesión Supabase cuyo `auth.uid()` mapee a un `app_user` activo del venue (las policies `*_venue_access` resuelven por `current_venue_id()`); la identidad por PIN de `verify_pin` es app-level y no habilita el drenaje.

Detalle de payloads y clasificación de errores: [sync/offline-first.md](../sync/offline-first.md).

## RPCs documentadas

| RPC | Inputs | Output | Notas |
|---|---|---|---|
| `verify_pin(p_venue_id, p_pin, p_display_name)` | `uuid, text, text?` | `{user_id, display_name, auth_status}` con `auth_status pin_auth_status` enum (`valid` \| `invalid` \| `blocked`) | SECURITY DEFINER. No expone `pin_hash`. Bloquea tras 5 intentos fallidos consecutivos (RF-AUTH-003). |
| `dashboard_kpis(p_venue_id, p_period)` | `uuid, text` (`'today'` \| `'7d'` \| `'30d'`) | jsonb con KPIs Capa 2: `{ventas_totales_cents, top_items, ticket_promedio_cents, hora_pico, ventas_por_dia[]}` | Capa 2. Aplica filtros temporales sin recargar (RF-ANALY-005). Performance: ≤1.5 s para 30 días con seed estándar (RNF-PERF-003). |
| `current_venue_id()` | — | `uuid` | Helper interno SECURITY DEFINER usado por las policies RLS. No se llama desde el cliente. |

Cada RPC nueva debe documentarse acá **en el mismo PR** que la introduce, con:

- Firma exacta (inputs y output).
- Si es SECURITY DEFINER, justificación.
- Caso de uso desde el frontend.
- Test pgTAP cubriendo casos válido / inválido / cross-venue.

## Realtime channels

```dart
// Suscripción KDS: escucha INSERT/UPDATE en customer_order del venue
supabase
  .channel('venue_${venueId}_orders')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'customer_order',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'venue_id',
      value: venueId,
    ),
    callback: (payload) => kitchenController.handleChange(payload),
  )
  .subscribe();
```

Convención de nombres de canal: `venue_<uuid>_<dominio>` (ej: `venue_<uuid>_orders`, `venue_<uuid>_menu`).

Limitaciones tier free Supabase: 200 conexiones realtime simultáneas; suficiente para academia.

## Storage

Buckets:

- `menu-images` — imágenes de ítems del menú. Lectura pública (URL firmada con TTL); escritura solo por owner del venue.

Convención de path: `<venue_id>/<menu_item_id>.<ext>`. La política de bucket replica el aislamiento por `venue_id`.

## Errores

El SDK retorna errores estructurados via `PostgrestException`:

| Código | Causa probable | Acción cliente |
|---|---|---|
| `42501` | RLS bloqueó la operación. | Verificar sesión; loguear caso a Sentry sin payload sensible. |
| `23503` | Foreign key violada. | Diagnóstico — probable bug de validación previa. |
| `23505` | Unique violation. | Mostrar mensaje al usuario (ej: ítem duplicado). |
| `PGRST*` | Error de PostgREST. | Loguear; reintentar si es transitorio. |
| Network | Sin conexión. | `SyncService` toma el control: encola en `pending_op`. |

## Versionado del contrato

- **Antes de Avance 2:** schema y RPCs son negociables; el equipo puede cambiar firmas en el mismo PR que ajusta el frontend.
- **Después de Avance 2:** cambios al schema o firma de RPC requieren ADR. Forward-only para datos en staging.

## Referencias

- [ADR-0002](../architecture/decisions/0002-supabase-baas-backend.md) — Supabase como backend único.
- [database/model.md](../database/model.md) — schema completo.
- [database/rls.md](../database/rls.md) — policies por tabla.
- [SRS § 4](../requirements/srs.md) — RNFs por categoría ISO 25010.
