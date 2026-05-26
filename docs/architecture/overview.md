# Arquitectura — overview

> Vista técnica del sistema en una página. Complementa el [SRS](../requirements/srs.md) (qué hace) explicando cómo está hecho. Para el por qué de cada decisión, ver [`decisions/`](decisions/).

## Resumen

COMAND-IA es una **app Flutter multiplataforma + Supabase** para comandas y analítica de locales gastronómicos micro. Un solo codebase corre en Android, iOS, web (CanvasKit) y desktop. La operación (toma de pedido, KDS realtime, cierre de cuenta) es **offline-first**: la app persiste localmente en Drift y sincroniza con Supabase cuando hay red. La analítica del owner es online y consulta Supabase directamente vía RPCs.

Multi-tenant desde el Sprint 1 por diseño: todas las tablas con datos de negocio tienen `venue_id` y RLS deny-by-default por venue. La arquitectura habilita Capa 3 (turismo regional B2G) sin refactor, aunque queda fuera del MVP académico.

## Estilo arquitectónico

**Cliente offline-first sobre BaaS gestionado**, sin microservicios propios. El frontend es la única pieza de software que el equipo escribe y opera; el backend es Supabase (Postgres + Auth + Realtime + Storage). Cada feature del frontend es un **vertical slice** con Clean Architecture liviana (`domain/` puro Dart, `data/` con datasources remoto/local, `presentation/` con controllers Riverpod + screens).

Tipo de proyecto en la matriz de la metodología: **BaaS-only**.

## Stack

| Capa | Tecnología | Notas |
|---|---|---|
| **Frontend** | Flutter 3.x | Un solo codebase para Android, iOS, web y desktop. Ver [ADR-0001](decisions/0001-flutter-multiplataforma.md). |
| **State management** | Riverpod 2.x + codegen | Controllers Riverpod inyectan repositorios abstractos (SOLID-D). [ADR-0003](decisions/0003-riverpod-codegen.md). |
| **Routing** | go_router | Deep links, guards de auth, shell routes. |
| **Persistencia local** | Drift (SQLite/IndexedDB) | Spike validatorio Sprint 1; fallback Hive si Flutter web da fricción. [ADR-0004](decisions/0004-drift-persistencia-local.md). |
| **Backend** | Supabase | Postgres + Auth + Realtime + Storage. [ADR-0002](decisions/0002-supabase-baas-backend.md). |
| **Multi-tenant** | Shared DB + RLS deny-by-default | Aislamiento por `venue_id` en cada tabla. [ADR-0005](decisions/0005-multi-tenancy-rls-deny-by-default.md). |
| **Hosting web** | Vercel | Preview por PR; deploy prod por tag `v*`. Ver [release-process](../devops/release-process.md). |
| **Observabilidad** | Sentry + Supabase Dashboard + Vercel analytics | Ver [observability](../operations/observability.md). |
| **CI** | GitHub Actions | Ver [ci-cd](../devops/ci-cd.md). |

## Componentes principales

- **comand-ia-app** (Flutter) — UI, lógica de dominio, sync offline. Único deployable que el equipo controla.
- **local-cache** (Drift sobre SQLite/IndexedDB) — fuente de verdad durante offline; cola FIFO `pending_op`.
- **supabase-postgres** — fuente de verdad remota; RLS, triggers y RPCs.
- **supabase-auth** (GoTrue) — magic link para owner, JWT para sesiones.
- **supabase-realtime** — WebSocket para KDS y sync de estados.
- **supabase-storage** — imágenes de ítems del menú.
- **sentry-saas** — excepciones y breadcrumbs del frontend.

## Principios de diseño

- **Offline-first** — la app funciona sin internet. Supabase es destino final, no requisito de operación.
- **Multi-tenant by default** — `venue_id` y RLS habilitada desde Sprint 1; nunca "después".
- **Calidad antes de scope** — si el sprint aprieta, se recortan features, no tests ni revisión.
- **YAGNI estructural** — pubspec único; carpetas `apps/`/`packages/` solo si aparece `apps/landing` (Sprint 5+).
- **Lenguaje del dominio en el código** — los identifiers siguen el [glosario](../product/glossary.md); renombres canónicos `dining_table`/`customer_order` para evitar colisión SQL.

## Decisiones clave

- [ADR-0001](decisions/0001-flutter-multiplataforma.md) — Flutter multiplataforma como frontend único.
- [ADR-0002](decisions/0002-supabase-baas-backend.md) — Supabase como backend único (BaaS-only).
- [ADR-0003](decisions/0003-riverpod-codegen.md) — Riverpod 2.x con codegen.
- [ADR-0004](decisions/0004-drift-persistencia-local.md) — Drift como persistencia local (con fallback Hive).
- [ADR-0005](decisions/0005-multi-tenancy-rls-deny-by-default.md) — Multi-tenancy por `venue_id` + RLS deny-by-default.
- [ADR-0006](decisions/0006-license-agpl-3.md) — Licencia AGPL-3.0.
- [ADR-0007](decisions/0007-github-flow-conventional-commits.md) — GitHub Flow + squash + Conventional Commits.
- [ADR-0008](decisions/0008-sync-offline-first-fifo-lww.md) — Sync offline-first FIFO + LWW server-side.

## Diagramas y vistas

- [C4 Context](c4-context.md) — sistema y actores externos.
- [C4 Container](c4-container.md) — contenedores y stacks.
- [Invariants](invariants.md) — ACID-1..7 y aplicación de SOLID.

## Documentación cruzada

- Modelo de datos: [database/model.md](../database/model.md) · [database/rls.md](../database/rls.md) · [database/migrations.md](../database/migrations.md).
- Sync offline-first: [sync/offline-first.md](../sync/offline-first.md).
- Contratos del backend: [api/contracts.md](../api/contracts.md).
- Observabilidad: [operations/observability.md](../operations/observability.md).
- Estrategia de pruebas: [quality/testing-strategy.md](../quality/testing-strategy.md).
