---
adr: 0002
title: Supabase como backend único (BaaS, sin microservicios)
status: accepted
date: 2026-04-27
deciders: Benjamín López
tags: [adr, arquitectura, backend, baas]
---

# ADR 0002 — Supabase como backend único (BaaS, sin microservicios)

## Contexto

El equipo tiene 2 personas y ~20 h/sprint efectivas. Diseñar, desplegar y operar microservicios propios (API Gateway, servicio de auth, servicio de pedidos, observabilidad propia) consumiría la mayor parte del tiempo en infra en lugar de features.

El dominio del problema (comandas + analítica para un local) **no requiere escala horizontal independiente por servicio**: la carga es por venue (decenas de usuarios concurrentes en el peor caso), no por endpoint. Las necesidades reales del backend son: persistencia relacional con multi-tenant, auth con magic link y PIN, realtime para el KDS y storage para imágenes del menú.

Supabase ofrece los cuatro como un único producto gestionado sobre Postgres + GoTrue + Realtime + Storage. El tier gratuito (500 MB DB, 200 conexiones realtime simultáneas, 2M mensajes/mes) es suficiente para el contexto académico.

## Decisión

Adoptamos **Supabase como único backend** del sistema: Postgres + Auth + Realtime + Storage. El frontend usa el SDK `supabase-dart` directamente — no hay capa REST artesanal entre la app y Supabase, ni microservicios propios.

El aislamiento entre tenants se hace por **RLS sobre `venue_id`** (ver [ADR-0005](0005-multi-tenancy-rls-deny-by-default.md)), no por bases de datos separadas ni por schemas independientes.

Implicaciones para el repo (tipo BaaS-only en la matriz de la metodología):

- `docs/api/openapi.yaml` no aplica → fuente de verdad del contrato vive en `docs/api/contracts.md` (schema + RPCs + tipos generados con `supabase gen types --lang dart`).
- `/healthz` y `/readyz` no aplican (no controlamos servidor propio).
- `docs/operations/runbook.md` reducido a lo que sí controlamos: rollback de migraciones y rollback de tag frontend en Vercel.
- Twelve-Factor parcial: puntos 4 (backing services), 7 (port binding) y 8 (concurrency) los maneja Supabase.

## Alternativas consideradas

### Opción A — Backend HTTP propio con Postgres
- **Pros:** Control total de endpoints; sin acoplamiento a proveedor; portable.
- **Contras:** Hay que diseñar, desplegar y operar API + auth + realtime; meses de plumbing antes de la primera feature; fuera del presupuesto en horas/semestre.
- **Por qué se descartó:** Costo operativo desproporcionado para 2 personas en 10 sprints.

### Opción B — Firebase
- **Pros:** Realtime maduro; SDK Flutter bien soportado; tier free generoso.
- **Contras:** Firestore es NoSQL → la analítica relacional (totales por venue, top items, ticket promedio) se vuelve dolorosa; sin RLS equivalente a Postgres (las security rules son menos potentes); lock-in fuerte a GCP.
- **Por qué se descartó:** El dominio es claramente relacional (`customer_order` → `order_item` → `menu_item`); forzarlo en un store de documentos pierde el SQL que ya conocemos.

### Opción C — Supabase (elegida)
- **Pros:** Postgres real con RLS; auth, realtime, storage incluidos; tipos type-safe generados desde el schema; tier free suficiente; SDK Flutter oficial activo.
- **Contras explícitos:** Acoplamiento al proveedor; realtime limitado a 200 conexiones simultáneas en free tier; edge functions Deno son optativas y no son la fortaleza del producto.

### Opción D — PocketBase / AppWrite
- **Pros:** Self-hosted, open-source, sin lock-in.
- **Contras:** SDK Flutter menos maduro; obligan a operar el servidor (volvemos al problema de Opción A).
- **Por qué se descartó:** Replica el costo operativo del backend propio.

## Consecuencias

### Positivas
- Cero tiempo en configurar servidores, load balancers ni deployment de API.
- Auth, realtime y storage resueltos con configuración, no con código.
- `supabase gen types --lang dart` genera tipos type-safe desde el schema real → cambios de schema se detectan en compilación.
- Postgres + RLS habilita multi-tenant deny-by-default sin lógica de aplicación (ver [ADR-0005](0005-multi-tenancy-rls-deny-by-default.md)).

### Negativas / costo
- Acoplamiento al proveedor. Mitigación: la capa `data/datasources/remote/` abstrae el SDK; cambiar de backend no toca el dominio (RNF-PORT-002).
- Realtime limitado a 200 conexiones simultáneas en free tier. Documentado en SRS § 2.4.
- Edge functions (Deno) son optativas; solo se usan si Postgres + RLS no alcanzan. No se construyen "por si acaso".

### Neutras
- El backend "vive" en el dashboard de Supabase (no en el repo). La doc de schema y RLS vive en `docs/database/`; las migraciones SQL son la fuente de verdad versionada.
- Observabilidad parcial: lo del cliente va a Sentry (lo controlamos); lo del servidor va al Supabase Dashboard (lo consultamos).

## Cumplimiento / verificación

- CI ejecuta `supabase db reset` en cada PR — todas las migraciones deben aplicarse limpias desde cero.
- CI ejecuta `supabase test db` (pgTAP) — RLS y contratos SQL verificados.
- Code review chequea que no se introduzca lógica de negocio en una "capa REST" intermedia: el frontend habla directo con Supabase a través del repositorio del feature.
- Toda nueva tabla con `venue_id` viene con RLS habilitada y test pgTAP cross-venue en el mismo PR.

## Referencias

- [SRS § 2.4 Restricciones](../../requirements/srs.md)
- [Architecture Overview](../overview.md), [C4 Container](../c4-container.md).
- ADRs relacionados: [ADR-0005](0005-multi-tenancy-rls-deny-by-default.md) (RLS), [ADR-0008](0008-sync-offline-first-fifo-lww.md) (sync).
