---
adr: 0005
title: Multi-tenancy por venue_id + RLS deny-by-default
status: accepted
date: 2026-04-27
deciders: Benjamín López
tags: [adr, seguridad, persistencia, multi-tenancy]
---

# ADR 0005 — Multi-tenancy por `venue_id` + RLS deny-by-default

## Contexto

COMAND-IA es **multi-tenant por diseño desde Sprint 1**: múltiples locales gastronómicos comparten la misma base de datos Supabase (RNF-SEC-001..002). El aislamiento de datos entre tenants es **requisito de seguridad crítico** — un local no puede ver pedidos, menú, mesas ni analítica de otro local — y se valida en pgTAP cross-venue (CA-002, CA-007, CA-104).

Además, la arquitectura debe soportar **Capa 3** (turismo regional B2G con datos agregados anonimizados) sin refactor del schema, lo que exige que `venue_id` esté presente desde el principio.

Tres patrones canónicos de multi-tenancy en Postgres:

1. **DB por tenant** — máximo aislamiento, máximo costo operativo.
2. **Schema por tenant** — aislamiento medio; migraciones complejas (N schemas a mantener).
3. **Shared DB con RLS** — aislamiento por policy a nivel de fila; un solo schema; migraciones simples.

El equipo es de 2 personas y usa Supabase free tier (sin múltiples DBs disponibles). El volumen esperado es bajo (decenas de venues como máximo en horizonte académico). El costo de operar N schemas o N DBs es desproporcionado.

## Decisión

Adoptamos **shared DB con RLS deny-by-default** en Postgres. Toda tabla con datos de negocio incluye columna `venue_id`. La policy genérica en cada tabla es:

```sql
CREATE POLICY "venue_isolation" ON <tabla>
  USING (venue_id = current_venue_id());
```

`current_venue_id()` es una función `SECURITY DEFINER` que consulta `app_user` sin disparar recursión de policies.

**RLS habilitada desde Sprint 1, no "después"**. Si una tabla nueva se agrega sin policy explícita, todas las queries retornan 0 filas (deny-by-default de Postgres cuando RLS está habilitada).

**Casos especiales:**

| Tabla | Policy especial |
|---|---|
| `staff_pin` | SELECT bloqueado completamente. Lectura solo via `verify_pin()` SECURITY DEFINER para no exponer `pin_hash`. |
| `venue` | El owner puede crear y ver venues donde `owner_id = auth.uid()`. |
| `audit_log` | INSERT desde SECURITY DEFINER trigger. SELECT solo para owner del venue. |

## Alternativas consideradas

### Opción A — DB por tenant
- **Pros:** Aislamiento físico; sin riesgo de leak por bug en policy.
- **Contras:** Costo operativo alto (N DBs, N migraciones, N usuarios); incompatible con Supabase free tier.
- **Por qué se descartó:** No escala con el equipo ni con el plan.

### Opción B — Schema por tenant
- **Pros:** Aislamiento lógico; queries cruzadas posibles con privilegios.
- **Contras:** Migraciones complejas (cada nuevo schema tiene que aplicar todas); search_path por sesión es frágil; no es el patrón natural de Supabase.
- **Por qué se descartó:** Costo de mantenimiento alto sin ganancia clara sobre RLS.

### Opción C — Lógica de aislamiento en la aplicación (sin RLS)
- **Pros:** Más fácil de partir.
- **Contras:** Un bug en el cliente o un endpoint mal validado expone datos cross-venue; no se puede demostrar aislamiento con un test SQL.
- **Por qué se descartó:** Imposible de defender en un proyecto con foco en calidad — el aislamiento no puede depender solo de "que el dev se acuerde de filtrar".

### Opción D — Shared DB con RLS deny-by-default (elegida)
- **Pros:** Aislamiento enforced por Postgres, no por aplicación; un solo schema y migraciones simples; soporta Capa 3 sin cambios; testeable con pgTAP.
- **Contras explícitos:** JOINs entre tablas pueden filtrar filas inesperadamente si una de las tablas del JOIN no tiene policy equivalente; cada tabla nueva necesita test pgTAP cross-venue en el mismo PR.

## Consecuencias

### Positivas
- Un solo schema; migraciones simples y uniformes para todos los tenants.
- El aislamiento es **enforced por Postgres**, no por lógica de aplicación. Es más difícil de bypassear accidentalmente.
- Soporta Capa 3 (datos agregados) sin cambios de schema: las vistas de analítica ya tienen `venue_id`.
- pgTAP cross-venue es la fuente de verdad de "ningún venue ve datos de otro" → CI bloquea regresiones (RNF-SEC-002).

### Negativas / costo
- JOINs entre tablas pueden filtrar filas inesperadamente si una de las tablas del JOIN no tiene policy equivalente. Mitigación: cada migración con tabla nueva incluye test pgTAP cross-venue desde Sprint 1.
- `staff_pin` requiere tratamiento especial (SELECT bloqueado, acceso solo via `verify_pin()` SECURITY DEFINER). Documentado como invariante ACID-6.
- Diagnosticar "queries que retornan 0 filas" puede ser confuso si se olvida `current_venue_id()` (típicamente al ejecutar SQL desde Studio sin JWT).

### Neutras
- El schema se mantiene como **forward-only en MVP** (RNF-SEC-005); rollback manual si se necesita.
- Capa 3 (turismo regional B2G) queda habilitada arquitectónicamente sin trabajo extra.

## Cumplimiento / verificación

- pgTAP nightly verifica que toda tabla con `venue_id` en `public` tiene al menos una policy USING (ver `supabase/tests/`):

```sql
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
```

- Test cross-venue: token de venue B intenta SELECT sobre `customer_order` de venue A → 0 filas (RNF-SEC-002, CA-007).
- Code review: PR que agrega tabla con `venue_id` debe incluir policy USING + test pgTAP en el mismo cambio.
- Invariante ACID-5 documentado en `docs/architecture/invariants.md`.

## Referencias

- [SRS § 4.5 Security](../../requirements/srs.md) — RNF-SEC-001..005.
- [SRS § 5 Casos de aceptación](../../requirements/srs.md) — CA-002, CA-007, CA-104.
- [Database RLS](../../database/rls.md), [Database Model](../../database/model.md).
- [Security baseline](../../security/security.md), [Threat model](../../security/threat-model.md).
- ADRs relacionados: [ADR-0002](0002-supabase-baas-backend.md).
