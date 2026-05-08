# Migraciones — política y convenciones

> Forward-only en MVP. Cada migración es una pieza inmutable del historial; los cambios incompatibles se aplican como nueva migración correctiva.

## Ubicación

Las migraciones viven en `supabase/migrations/` con numeración ascendente:

```
supabase/migrations/
├── 0001_init.sql           ← schema base + RLS + triggers + RPCs MVP
└── NNNN_<slug>.sql         ← cambios forward-only futuros
```

El nombre del archivo sigue el convenio de Supabase CLI: `<timestamp>_<slug>.sql` o `NNNN_<slug>.sql` con padding consistente.

## Política

- **Forward-only en MVP.** No hay migraciones de rollback. Si algo falla en producción (post-defensa), se aplica una nueva migración correctiva.
- **Idempotentes cuando sea posible.** Preferir `CREATE OR REPLACE`, `IF NOT EXISTS`, `DROP ... IF EXISTS`. Si la migración no puede ser idempotente, documentarlo en el header del archivo.
- **Una migración por PR si toca esquema.** Excepción: si dos cambios son indivisibles (renombre + actualización de policy), se permiten en la misma migración con justificación en el commit.
- **Nunca editar una migración ya aplicada en staging o prod.** Reescribir historia rompe el schema en cualquier entorno que ya la haya aplicado.
- **Si un cambio afecta RLS o reglas, en el mismo PR se actualiza el test pgTAP correspondiente** (ver [rls.md](rls.md)).

## CI

- `supabase db reset` se ejecuta en cada PR — todas las migraciones deben aplicarse limpias desde cero. Si una migración falla, el PR no mergea.
- Tras `db reset`, se ejecuta `supabase test db` (pgTAP) para verificar contratos SQL y RLS.
- `seed.sql` se aplica en el mismo `db reset` — sirve como dataset determinista para tests y demo.

## Header recomendado de cada migración

```sql
-- 0002_add_payment_method_per_venue.sql
-- Motivo: COMA-145 — owner puede definir métodos de pago por venue.
-- Backwards-compatible: sí. Idempotente: sí (CREATE TABLE IF NOT EXISTS).
-- ADRs relacionados: -
-- Fecha: 2026-06-XX
```

## Cambios incompatibles (rename, drop, type change)

Cuando un cambio rompe contrato (renombrar columna, cambiar tipo, eliminar tabla):

1. Migración A — agrega la nueva columna/tabla con `default` o `nullable`.
2. Despliegue de la app actualizada que escribe en ambas formas.
3. Migración B — backfill de datos.
4. Migración C — elimina la columna/tabla antigua.

Cada paso es una migración separada con su PR, su review y su tag. Para el MVP académico, este flujo se aplica solo si afecta datos reales que no se pueden regenerar con `seed.sql`.

## Migraciones locales de Drift

Las migraciones locales (Drift) son **independientes** de las de Supabase. Viven en el código Dart bajo el paquete de Drift y siguen su propio versionado de schema (`schemaVersion` en la base Drift). No se confunden con las migraciones SQL del backend.

## Referencias

- [SRS § 4.5 Security](../requirements/srs.md) — RNF-SEC-005 (forward-only en MVP).
- [database/model.md](model.md), [database/rls.md](rls.md).
- ADR relacionado: [ADR-0002](../architecture/decisions/0002-supabase-baas-backend.md).
