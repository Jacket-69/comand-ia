# Row-Level Security (RLS) — deny-by-default

> Aislamiento entre venues vía RLS de Postgres. Habilitada desde Sprint 1, no "después". Decisión: [ADR-0005](../architecture/decisions/0005-multi-tenancy-rls-deny-by-default.md). Invariante: ACID-5.

## Patrón general

Toda tabla con `venue_id` tiene RLS habilitada y al menos una policy USING. La policy genérica es:

```sql
-- Patrón aplicado a cada tabla con venue_id
ALTER TABLE <tabla> ENABLE ROW LEVEL SECURITY;

CREATE POLICY "venue_isolation" ON <tabla>
  USING (venue_id = current_venue_id());
```

`current_venue_id()` es una función `SECURITY DEFINER` que consulta `app_user` para obtener el `venue_id` del usuario autenticado, sin disparar recursión de policies sobre la propia `app_user`.

**Si una tabla nueva se agrega sin policy explícita, todas las queries retornan 0 filas** (deny-by-default de Postgres cuando RLS está habilitada).

## Casos especiales

| Tabla | Policy especial | Motivo |
|---|---|---|
| `staff_pin` | SELECT bloqueado completamente; lectura solo vía `verify_pin()` SECURITY DEFINER. | Evita exponer `pin_hash` aunque sea con RLS de venue. ACID-6. |
| `venue` | El owner puede crear y ver venues donde `owner_id = auth.uid()`. | El owner tiene rol especial: es dueño del tenant raíz. |
| `audit_log` | INSERT desde SECURITY DEFINER trigger. SELECT solo para owner del venue. | Garantiza que el log de auditoría no se borre desde un usuario `staff`. |

## Audit nightly con pgTAP

```sql
-- Verificación automática en nightly CI
SELECT plan(1);
SELECT ok(
  (SELECT count(*) FROM pg_tables t
   WHERE t.schemaname = 'public'
     AND t.tablename IN ('venue','app_user','menu_item','customer_order',
                         'order_item','dining_table','menu_category')
     AND NOT EXISTS (
       SELECT 1 FROM pg_policies p
       WHERE p.schemaname = 'public' AND p.tablename = t.tablename
     )
  ) = 0,
  'Todas las tablas con venue_id tienen al menos una policy RLS'
);
SELECT finish();
```

Tests adicionales en `supabase/tests/`:

- **Cross-venue:** token de venue B intenta SELECT/UPDATE/DELETE sobre tablas de venue A → 0 filas.
- **`pin_hash` no leíble:** SELECT directo sobre `staff_pin.pin_hash` desde el cliente → bloqueado por RLS, retorna 0 filas.
- **`pending_op` no existe en Supabase:** verifica que la tabla local-only no figure en `information_schema.tables` del schema público.

## Cuándo se rompe la garantía RLS

JOINs entre tablas pueden filtrar filas inesperadamente si una de las tablas del JOIN no tiene policy equivalente. Ejemplo:

```sql
-- INCORRECTO: si menu_item de venue A se relaciona con order_item de venue B (imposible por ACID-1)
SELECT mi.* FROM menu_item mi JOIN order_item oi ON oi.menu_item_id = mi.id;
```

Mitigación: cada migración que agrega tabla con `venue_id` viene con test pgTAP cross-venue **en el mismo PR**, y los JOINs en queries de aplicación no asumen aislamiento — siempre se filtran explícitamente por `venue_id`.

## Aplicar policies a tabla nueva

Checklist al agregar tabla con datos de negocio:

1. Columna `venue_id` (uuid not null, fk a `venue`).
2. Trigger `set_updated_at()` aplicado.
3. RLS habilitada (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`).
4. Policy `venue_isolation` (USING + WITH CHECK si hay INSERT/UPDATE).
5. Test pgTAP cross-venue en `supabase/tests/`.
6. Si la tabla guarda datos sensibles, evaluar caso especial (como `staff_pin`).

## Referencias

- [ADR-0005](../architecture/decisions/0005-multi-tenancy-rls-deny-by-default.md) — Multi-tenancy + RLS deny-by-default.
- [SRS § 4.5 Security](../requirements/srs.md) — RNF-SEC-001..004.
- [SRS § 5 Casos de aceptación](../requirements/srs.md) — CA-002, CA-007, CA-104.
- [database/model.md](model.md), [security/security.md](../security/security.md), [security/threat-model.md](../security/threat-model.md).
