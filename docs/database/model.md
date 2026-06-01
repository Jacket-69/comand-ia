# Modelo de datos

> Tablas, relaciones, invariantes y triggers del schema Postgres en Supabase. Para RLS ver [rls.md](rls.md). Para política de migraciones ver [migrations.md](migrations.md).

## Tablas principales

| Tabla | Columnas clave | Notas |
|---|---|---|
| `venue` | `id` (uuid PK), `name`, `owner_id` (fk auth.users), `settings` (jsonb), `created_at` | Tenant raíz. Una fila = un local. |
| `app_user` | `id` (= auth.users.id), `email`, `role` (`owner` \| `staff`), `venue_id`, `display_name`, `created_at` | El owner crea primero `venue` y luego su `app_user` asociado en el onboarding. |
| `staff_pin` | `id`, `venue_id`, `app_user_id`, `pin_hash`, `failed_attempts`, `locked_until` | `pin_hash` vía `pgcrypto.crypt()`. SELECT bloqueado por RLS; solo `verify_pin()` SECURITY DEFINER. ACID-6. |
| `menu_category` | `id`, `venue_id`, `name`, `sort_order`, `active`, `updated_at` | |
| `menu_item` | `id`, `venue_id`, `category_id`, `name`, `price_cents` (int), `active`, `image_url`, `updated_at` | Precio en centavos (no float). |
| `dining_table` | `id`, `venue_id`, `label`, `capacity`, `active`, `updated_at` | Renombrado desde `table` para evitar colisión SQL. |
| `customer_order` | `id`, `venue_id`, `dining_table_id`, `status` (`open` \| `sent` \| `preparing` \| `ready` \| `closed` \| `cancelled`), `opened_by`, `opened_at`, `closed_at`, `total_cents`, `tip_cents`, `payment_method`, `notes`, `updated_at` | `total_cents` calculado por trigger; el cliente nunca lo escribe. `tip_cents` (int, default 0) es la propina del comensal: separada de `total_cents`, se fija al cerrar la cuenta. ACID-3. |
| `order_item` | `id`, `venue_id`, `order_id`, `menu_item_id`, `name_snapshot`, `price_cents_snapshot`, `quantity`, `comments`, `status`, `updated_at` | Snapshots inmutables al INSERT. ACID-2. |
| `pending_op` | `id`, `venue_id`, `op_type`, `payload` (jsonb), `created_at`, `attempts` | **Local-only (Drift). Cola FIFO de sincronización. No existe en Supabase.** ACID-7. |
| `audit_log` | `id`, `venue_id`, `app_user_id`, `action`, `entity`, `entity_id`, `diff` (jsonb), `at` | Trazabilidad mínima de mutaciones importantes. |

## Convenciones

- **Precios siempre en centavos (`int`).** El frontend formatea a CLP en el borde de UI. Sin floats.
- **`venue_id` en toda tabla de negocio.** Es el eje del multi-tenancy. Sin excepciones; sin policy explícita una tabla nueva queda inaccesible (deny-by-default).
- **Renombres canónicos** para evitar colisión con palabras reservadas SQL: `dining_table` (no `table`), `customer_order` (no `order`).
- **`updated_at`** lo asigna el trigger `set_updated_at()` en cada UPDATE; el cliente nunca lo escribe.
- **Snapshots inmutables** en `order_item`: `name_snapshot` y `price_cents_snapshot` se fijan al INSERT. ACID-2.
- **Estado terminal** en `customer_order.status = 'closed'`: bloquea UPDATE posterior. ACID-4.

## Triggers SQL clave

```sql
-- set_updated_at: actualiza updated_at en toda tabla antes de UPDATE
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
-- Aplicar: CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON <tabla>
--          FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- compute_order_total: recalcula total del pedido tras mutación en order_item
CREATE OR REPLACE FUNCTION compute_order_total()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE customer_order
  SET total_cents = (
    SELECT COALESCE(SUM(price_cents_snapshot * quantity), 0)
    FROM order_item
    WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
      AND status != 'cancelled'
  )
  WHERE id = COALESCE(NEW.order_id, OLD.order_id);
  RETURN NEW;
END;
$$;

-- verify_pin: valida PIN sin exponer pin_hash al cliente
CREATE OR REPLACE FUNCTION verify_pin(
  p_venue_id uuid,
  p_pin text,
  p_display_name text DEFAULT NULL
)
RETURNS TABLE(user_id uuid, display_name text, auth_status pin_auth_status)
LANGUAGE plpgsql SECURITY DEFINER AS $$ ... $$;
```

`compute_order_total` y `verify_pin` son `SECURITY DEFINER` deliberadamente: necesitan acceso a tablas que el cliente tiene bloqueadas por RLS (`order_item` para sumar, `staff_pin` para validar el hash).

## Relaciones (ERD resumido)

```
venue 1───* app_user
venue 1───* dining_table
venue 1───* menu_category 1───* menu_item
venue 1───* customer_order *───1 dining_table
customer_order 1───* order_item *───1 menu_item
venue 1───* staff_pin
```

Toda fila descendiente de `venue` lleva `venue_id` denormalizado para que la policy RLS sea uniforme y no requiera JOINs cross-table que la matriz pueda romper. Ver [rls.md](rls.md).

## Diccionario por columna

Documentado en el SRS § 1.3 ([requirements/srs.md](../requirements/srs.md)) y en `lib/core/db_types.dart` (generado por `supabase gen types --lang dart`).

## Referencias

- [SRS](../requirements/srs.md)
- [database/rls.md](rls.md) — policies por tabla.
- [database/migrations.md](migrations.md) — política forward-only.
- [architecture/invariants.md](../architecture/invariants.md) — ACID-1..7.
- [api/contracts.md](../api/contracts.md) — RPCs y tipos generados.
